/*
	File:		authapp.c

	Copyright: 	© Copyright 2002 Apple Computer, Inc. All rights reserved.
	
	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
                        ("Apple") in consideration of your agreement to the following terms, and your
                        use, installation, modification or redistribution of this Apple software
                        constitutes acceptance of these terms.  If you do not agree with these terms,
                        please do not use, install, modify or redistribute this Apple software.
                        
                        In consideration of your agreement to abide by the following terms, and subject
                        to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
                        copyrights in this original Apple software (the "Apple Software"), to use,
                        reproduce, modify and redistribute the Apple Software, with or without
                        modifications, in source and/or binary forms; provided that if you redistribute
                        the Apple Software in its entirety and without modifications, you must retain
                        this notice and the following text and disclaimers in all such redistributions of
                        the Apple Software.  Neither the name, trademarks, service marks or logos of
                        Apple Computer, Inc. may be used to endorse or promote products derived from the
                        Apple Software without specific prior written permission from Apple.  Except as
                        expressly stated in this notice, no other rights or licenses, express or implied,
                        are granted by Apple herein, including but not limited to any patent rights that
                        may be infringed by your derivative works or by other works in which the Apple
                        Software may be incorporated.
                        
                        The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
                        WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
                        WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
                        PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                        COMBINATION WITH YOUR PRODUCTS.
                        
                        IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
                        CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                        GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
                        ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                        OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
                        (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
                        ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
				
	Change History (most recent first):
                05/19/02	davelopper@users.sourceforge.net: adapted for GPGPreferences

                5/1/02		2.0d2		Improved the reliability of determining the path to the
                                        executable during self-repair.

                02/27/02	davelopper@users.sourceforge.net: adapted for GPGPreferences

                12/19/01	2.0d1		First release of self-repair version.
*/


#include "authinfo.h"

#include <Security/AuthorizationTags.h>
#include <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>



static bool
pathForTool(CFStringRef toolName, char path[MAXPATHLEN], CFBundleRef bundle)
{
//    CFBundleRef bundle;
    CFURLRef resources;
    CFURLRef toolURL;
    Boolean success = true;
    
//    bundle = CFBundleGetMainBundle();
    if (!bundle)
        return FALSE;
    
    resources = CFBundleCopyResourcesDirectoryURL(bundle);
    if (!resources)
        return FALSE;
    
    toolURL = CFURLCreateCopyAppendingPathComponent(NULL, resources, toolName, FALSE);
    CFRelease(resources);
    if (!toolURL)
        return FALSE;
    
    success = CFURLGetFileSystemRepresentation(toolURL, TRUE, (UInt8 *)path, MAXPATHLEN);
    
    CFRelease(toolURL);
    return !access(path, X_OK);
}




/* Return one of our defined error codes. */
static int
performCommand(AuthorizationRef authorizationRef, MyAuthorizedCommand myCommand, CFBundleRef bundle)
{
    char path[MAXPATHLEN];
    int comms[2] = {};
    int childStatus = 0;
    int written;
    pid_t pid;

    AuthorizationExternalForm extAuth;

    if (!pathForTool(CFSTR("authtool"), path, bundle))
    {
        /* The tool could disappear from inside the application's package if a user tries to copy the
        application.  Currently, the Finder will complain that it doesn't have permission to copy the
        tool and if the user decides to go ahead with the copy, the application gets copied without
        the tool inside.  At this point, you should recommend that the user re-install the application. */
        
        IFDEBUG(fprintf(stderr, "The authtool could not be found at path '%s'.\n", path);)
        return kMyAuthorizedCommandInternalError;
    }
    
    /* Turn an AuthorizationRef into an external "byte blob" form so it can be transmitted to the authtool. */
    if (AuthorizationMakeExternalForm(authorizationRef, &extAuth))
        return kMyAuthorizedCommandInternalError;

    /* Create a descriptor pair for interprocess communication. */
    if (pipe(comms))
        return kMyAuthorizedCommandInternalError;

    switch(pid = fork())
    {
        case 0:	/* Child */
        {            
            char *const envp[] = { NULL };

            dup2(comms[0], 0);
            close(comms[0]);
            close(comms[1]);
            execle(path, path, NULL, envp);
            _exit(1);
        }
        case -1: /* an error occured */
            close(comms[0]);
            close(comms[1]);
            return kMyAuthorizedCommandInternalError;
        default: /* Parent */
            break;
    }

    /* Parent */
    /* Don't abort the program if write fails. */
    signal(SIGPIPE, SIG_IGN);
    
    /* Close input pipe since we are not reading from client. */
    close(comms[0]);


    IFDEBUG(fprintf(stderr, "Passing child externalized authref.\n");)

    /* Write the ExternalizedAuthorization to our output pipe. */
    if (write(comms[1], &extAuth, sizeof(extAuth)) != sizeof(extAuth))
    {
        close(comms[1]);
        return kMyAuthorizedCommandInternalError;
    }

    IFDEBUG(fprintf(stderr, "Passing child command.\n");)

    /* Write the commands we want to execute to our output pipe */
    written = write(comms[1], &myCommand, sizeof(MyAuthorizedCommand));
    
    /* Close output pipe to notify client we are done. */
    close(comms[1]);
    
    if (written != sizeof(MyAuthorizedCommand))
        return kMyAuthorizedCommandInternalError;

    /* Wait for the tool to return */
    if (waitpid(pid, &childStatus, 0) != pid)
        return kMyAuthorizedCommandInternalError;

    if (!WIFEXITED(childStatus)){
        // WARNING: it happened that task would fail here, childStatus being 13 = SIGPIPE
        // I needed to reboot machine, relaunching SystemPrefs wasn't enough.
        // Bug here? I should ask Apple.
        return kMyAuthorizedCommandInternalError;
    }    
    return WEXITSTATUS(childStatus);
}




OSStatus
GPGPreferences_ExecuteAdminCommand(const char *rightName, int authorizedCommandOperation, const char *fileArgument, uid_t uid, gid_t gid, mode_t mode, CFBundleRef bundle)
{
    AuthorizationRef authorizationRef;
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights;
    AuthorizationItem right = { rightName, 0, NULL, 0 };
    AuthorizationRights rightSet = { 1, &right };
    MyAuthorizedCommand myCommand;
    OSStatus status;

    /* Create a new authorization reference which will later be passed to the tool. */
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);

    if (status != errAuthorizationSuccess)
    {
        IFDEBUG(fprintf(stderr, "Failed to create the authref: %ld.\n", status));
        return kMyAuthorizedCommandInternalError;
    }

    /* This shows how AuthorizationCopyRights() can be used in order to pre-authorize the user before
    attempting to perform the privileged operation.  Pre-authorization is optional but can be useful in
    certain situations.  For example, in the Installer application, the user is asked to pre-authorize before
    configuring the installation because it would be a waste of time to let the user proceed through the
    entire installation setup, only to be denied at the final stage because they weren't the administrator. */
    
    status = AuthorizationCopyRights(authorizationRef, &rightSet, kAuthorizationEmptyEnvironment, flags, NULL);

    if (status == errAuthorizationSuccess)
    {
        myCommand.authorizedCommandId = authorizedCommandOperation;
        strcpy(myCommand.file, fileArgument);
        myCommand.owner = uid;
        myCommand.group = gid;
        myCommand.mode = mode;

        status = performCommand(authorizationRef, myCommand, bundle);
        IFDEBUG(fprintf(stderr, "Performing the command returned %ld.\n", status);)


            /* Specifying the kAuthorizationFlagDestroyRights causes the granted rights to be destroyed so
            they can't be shared between sessions and used again.  Rights will automatically timeout by default
        after 5 minutes, but the timeout value can be changed by editing the file located at /etc/authorization.
            The config file gives System Administrators the ability to enforce a stricter security policy, and it's
            recommended that you test with a zero second timeout enabled to make sure your application continues
            to behave as expected. */

            AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
    }
    else
    {
        IFDEBUG(fprintf(stderr, "Pre-authorization failed, giving up.\n"));
        return kMyAuthorizedCommandInternalError;
    }
    
    return status;
}
