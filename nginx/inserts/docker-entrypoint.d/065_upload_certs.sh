#!/bin/sh

#set -x
#set -e

WEBSERVER_URL="http://web/cgi-bin/upload.php"

upload() {
    local FILE_NAME=${1}
    curl -X POST -u Admin:devolo --form "uploadedfile=@${FILE_NAME}" ${WEBSERVER_URL}
    UPLOAD_RESULT="${?}"
    mylogger "Uploaded ${FILE_NAME} to ${WEBSERVER_URL} result: ${UPLOAD_RESULT}" 
}

#############################################################

if [ -f ${CA_DIR}/upload ]; then

    for UPLOAD_FILE in $(find /root/ca/ | grep root.\\.); do
	upload ${UPLOAD_FILE}
    done

    for UPLOAD_FILE in $(find /root/ca/ | grep intermediate.\\.); do
	upload ${UPLOAD_FILE}
    done

    for UPLOAD_FILE in $(find /root/ca/ | grep cert$); do
	upload ${UPLOAD_FILE}
    done

    rm -f ${CA_DIR}/upload
else
    mylogger "No upload requested." 
fi
