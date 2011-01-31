To get a running prefPane:

for i in `find build/Debug/GnuPG.prefPane/Contents/Resources/ -name "*.prefPane"`; do cd $i/Contents; ln -s ../../../Frameworks; cd -; done

