/*
	File:		authtool.c

	Copyright: 	© Copyright 2001 Apple Computer, Inc. All rights reserved.
	
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
                02/27/02	davelopper@users.sourceforge.net: adapted for GPGPreferences
                12/19/01	2.0d1
*/


#include "authinfo.h"

#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <string.h>
#include <errno.h>

                                        


/* Return the name of the right to verify for the operation specified in myCommand. */
static const char *
rightNameForCommand(const MyAuthorizedCommand * myCommand)
{
    switch (myCommand->authorizedCommandId)
    {
        case kMyAuthorizedCommandMove:
            return "net.sourceforge.macgpg.GPGPreferences.moveGPG";
        case kMyAuthorizedCommandLink:
            return "net.sourceforge.macgpg.GPGPreferences.makeLinkForGPG";
    }
    return "system.unknown";
}




/* Perform the operation specified in myCommand. */
static bool
performOperation(const MyAuthorizedCommand * myCommand)
{
    if(mkdir("/usr/local", S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH))
        if(errno != EEXIST){
                perror(NULL);
                return false;
        }
    if(mkdir("/usr/local/bin", S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH))
        if(errno != EEXIST){
                perror(NULL);
                return false;
        }
//    fprintf(stderr, "performing Command %d on path %s\n", myCommand->authorizedCommandId, myCommand->file);

    switch(myCommand->authorizedCommandId){
        case kMyAuthorizedCommandMove:
            if(rename(myCommand->file, "/usr/local/bin/gpg")){
                perror(NULL);
                return false;
            }
            break;
        case kMyAuthorizedCommandLink:
            if(symlink(myCommand->file, "/usr/local/bin/gpg")){
                perror(NULL);
                return false;
            }
            break;
        default:
            return false;
    }
    
    return true;
}




int
main(int argc, char * const *argv)
{
    AuthorizationRef auth;
    int bytesRead;
    MyAuthorizedCommand myCommand;

    
    if (argc == 2 && !strcmp(argv[1], "--self-repair"))
    {
        /*  Self repair code.  We ran ourselves using AuthorizationExecuteWithPrivileges()
        so we need to make ourselves setuid root to avoid the need for this the next time around. */
        
        struct stat st;

        /* Recover the passed in AuthorizationRef. */
        if (AuthorizationCopyPrivilegedReference(&auth, kAuthorizationFlagDefaults))
            exit(kMyAuthorizedCommandInternalError);

        if (stat(argv[0], &st))
            exit(kMyAuthorizedCommandInternalError);

        if (st.st_uid != 0)
            chown(argv[0], 0, st.st_gid);

        /* Disable group and world writability and make setuid root. */
        chmod(argv[0], (st.st_mode & (~(S_IWGRP|S_IWOTH))) | S_ISUID);
    }
    else
    {
        AuthorizationExternalForm extAuth;

        /* Read the Authorization "byte blob" from our input pipe. */
        if (read(0, &extAuth, sizeof(extAuth)) != sizeof(extAuth))
            exit(kMyAuthorizedCommandInternalError);

        /* Restore the externalized Authorization back to an AuthorizationRef */
        if (AuthorizationCreateFromExternalForm(&extAuth, &auth))
            exit(kMyAuthorizedCommandInternalError);

        /* If we are not running as root we need to self-repair. */
        if (geteuid() != 0)
        {
            int status;
            int pid;
            FILE *commPipe = NULL;
            char *arguments[] = { "--self-repair", NULL };
            char buffer[1024];
            int bytesRead;

            /* Set our own stdin and stdout to be the communication channel with ourself. */
            
            if (AuthorizationExecuteWithPrivileges(auth, argv[0], kAuthorizationFlagDefaults, arguments, &commPipe))
                // Arrives here if user cancelled password query
                exit(kMyAuthorizedCommandInternalError);

            /* Read from stdin and write to commPipe. */
            for (;;)
            {
                bytesRead = read(0, buffer, 1024);
                if (bytesRead < 1) break;
                fwrite(buffer, 1, bytesRead, commPipe);
            }

            /* Flush any remaining output. */
            fflush(commPipe);
            
            /* Close the communication pipe to let the child know we are done. */
            fclose(commPipe);

            /* Wait for the child of AuthorizationExecuteWithPrivileges to exit. */
            pid = wait(&status);
            if (pid == -1 || ! WIFEXITED(status))
                exit(kMyAuthorizedCommandInternalError);

            /* Exit with the same exit code as the child spawned by AuthorizationExecuteWithPrivileges() */
            exit(WEXITSTATUS(status));
        }
    }


    /* Read a 'MyAuthorizedCommand' object from stdin. */
    bytesRead = read(0, &myCommand, sizeof(MyAuthorizedCommand));
    
    /* Make sure that we received a full 'MyAuthorizedCommand' object */
    if (bytesRead == sizeof(MyAuthorizedCommand))
    {
        const char *rightName = rightNameForCommand(&myCommand);
        AuthorizationItem right = { rightName, 0, NULL, 0 } ;
        AuthorizationRights rights = { 1, &right };
        AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed
                                    | kAuthorizationFlagExtendRights;
        
        /* Check to see if the user is allowed to perform the tasks stored in 'myCommand'. This may
        or may not prompt the user for a password, depending on how the system is configured. */
        
        if (AuthorizationCopyRights(auth, &rights, kAuthorizationEmptyEnvironment, flags, NULL))
            exit(kMyAuthorizedCommandAuthFailed);

        /* Perform the operation stored in 'myCommand'. */
        if (!performOperation(&myCommand))
            exit(kMyAuthorizedCommandOperationFailed);
    }
    else
    {
        exit(kMyAuthorizedCommandChildError);
    }
        
    exit(0);
}