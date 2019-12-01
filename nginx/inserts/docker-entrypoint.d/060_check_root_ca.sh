#!/bin/sh

#set -x
#set -e

## made from https://jamielinux.com/docs/openssl-certificate-authority/index.html

CA_DIR="/root/ca"
mkdir -p ${CA_DIR}
HOSTNAME=$(hostname)

#############################################################
COMMONNAME=${HOSTNAME}
COUNTRY=DE
STATE=NRW
LOCALITY=Aachen
ORGANIZATION="devolo AG"
ORGANIZATIONALUNIT=ENG
EMAIL=christian.katsch@devolo.de
#############################################################

ca_log() {
    MESSAGE="${*}"
    mylogger "${MESSAGE}" || echo "${MESSAGE}"
}

#############################################################

prepare_ca () {
    local CA_NAME=${1}
    local CA_POLICY=${2}
    local CA_SUPPORT_CSR=${3:-"no"}

    cd ${CA_DIR}
    mkdir ${CA_NAME}
    cd ${CA_NAME}

    mkdir certs crl newcerts private
    chmod 700 private
    touch index.txt
    touch index.txt.attr
    echo 1000 > serial
    cp /etc/my_openssl.cnf openssl.cnf
    sed -i "s/CA_NAME/${CA_NAME}/g" openssl.cnf
    sed -i "s/CA_POLICY/${CA_POLICY}/g" openssl.cnf

    if [ "${CA_SUPPORT_CSR}" != "no" ]; then
	# if can accpet csr
	mkdir csr
	echo 1000 > crlnumber
    fi
}

create_key () {
    KEY_NAME=${1}
    PASSPHRASE=${2}
    CA=${3}
    cd ${CA_DIR}
    openssl genrsa -aes256 -passout pass:${PASSPHRASE} -out ${CA}/private/${KEY_NAME}_with.key.pem 4096
    chmod 400 ${CA}/private/${KEY_NAME}_with.key.pem
    #Remove passphrase from the key. Comment the line out to keep the passphrase
    ca_log "Removing passphrase from key ${KEY_NAME}"
    openssl rsa -in ${CA}/private/${KEY_NAME}_with.key.pem -passin pass:${PASSPHRASE} -out ${CA}/private/${KEY_NAME}.key.pem
    chmod 400 ${CA}/private/${KEY_NAME}.key.pem
}

#############################################################

create_root_certificate () {
    local ROOT_CA_NAME=${1}
    local PASSPHRASE=${2}
    cd ${CA_DIR}/${ROOT_CA_NAME}
    openssl req -config openssl.cnf -key private/${ROOT_CA_NAME}.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/${ROOT_CA_NAME}.cert.pem -passin pass:$${PASSPHRASE} -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONALUNIT}/CN=${COMMONNAME} ${ROOT_CA_NAME} CA/emailAddress=${EMAIL}"
    chmod 444 certs/${ROOT_CA_NAME}.cert.pem
    openssl x509 -noout -text -in certs/${ROOT_CA_NAME}.cert.pem
    # chain consists only of this single one
    cp certs/${ROOT_CA_NAME}.cert.pem certs/ca-chain.cert.pem
}

create_root_ca () {
    local ROOT_CA_NAME=${1}
    local PASSPHRASE=${2}
    prepare_ca ${ROOT_CA_NAME} root support_csr
    create_key ${ROOT_CA_NAME} ${PASSPHRASE} ${ROOT_CA_NAME}
    create_root_certificate ${ROOT_CA_NAME} ${PASSPHRASE}
}

#############################################################

create_intermediate_certificate () {
    local INTERMEDIATE_CA_NAME=${1}
    local INTERMEDIATE_CA_PASSPHRASE=${2}
    local ROOT_CA_NAME=${3}
    local PASSPHRASE=${4}

    cd ${CA_DIR}
    openssl req -config ${INTERMEDIATE_CA_NAME}/openssl.cnf -key ${INTERMEDIATE_CA_NAME}/private/${INTERMEDIATE_CA_NAME}.key.pem -new -sha256 -out ${INTERMEDIATE_CA_NAME}/csr/${INTERMEDIATE_CA_NAME}.csr.pem -passin pass:${INTERMEDIATE_CA_PASSPHRASE} -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONALUNIT}/CN=${COMMONNAME} ${INTERMEDIATE_CA_NAME} CA/emailAddress=${EMAIL}"
    openssl ca -config ${ROOT_CA_NAME}/openssl.cnf -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -startdate 020501000000Z -in ${INTERMEDIATE_CA_NAME}/csr/${INTERMEDIATE_CA_NAME}.csr.pem -passin pass:${PASSPHRASE} -out ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.cert.pem -batch
    chmod 444 ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.cert.pem
    openssl x509 -noout -text -in ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.cert.pem
    openssl verify -CAfile ${ROOT_CA_NAME}/certs/${ROOT_CA_NAME}.cert.pem  ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.cert.pem
    cat ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.cert.pem ${ROOT_CA_NAME}/certs/${ROOT_CA_NAME}.cert.pem > ${INTERMEDIATE_CA_NAME}/certs/ca-chain.cert.pem
    chmod 444 ${INTERMEDIATE_CA_NAME}/certs/ca-chain.cert.pem
    cp ${INTERMEDIATE_CA_NAME}/certs/ca-chain.cert.pem ${INTERMEDIATE_CA_NAME}/certs/${INTERMEDIATE_CA_NAME}.chain.cert.pem
}

create_intermediate_ca () {
    local INTERMEDIATE_CA_NAME=${1}
    local INTERMEDIATE_CA_PASSPHRASE=${2}
    local ROOT_CA=${3}
    local PASSPHRASE=${2}

    prepare_ca ${INTERMEDIATE_CA_NAME} intermediate support_csr
    create_key ${INTERMEDIATE_CA_NAME} ${INTERMEDIATE_CA_PASSPHRASE} ${INTERMEDIATE_CA_NAME}
    create_intermediate_certificate ${INTERMEDIATE_CA_NAME} ${INTERMEDIATE_CA_PASSPHRASE} ${ROOT_CA} ${PASSPHRASE}
}

#############################################################

create_certificate_sign_request ()  {
    KEY_NAME=${1}
    NEW_COMMONNAME=${2}
    PASSPHRASE=${3}
    CA=${4}

    cd ${CA_DIR}
    openssl req -config ${CA}/openssl.cnf -key ${CA}/private/${KEY_NAME}.key.pem -new -sha256 -out ${CA}/csr/${KEY_NAME}.csr.pem -passin pass:${PASSPHRASE} -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONALUNIT}/CN=${NEW_COMMONNAME}/emailAddress=${EMAIL}"
}

sign_certificate_sign_request () {
    KEY_NAME=${1}
    PASSPHRASE=${2}
    CA=${3}
    PURPOSE=${4}

    cd ${CA_DIR}
    openssl ca -config ${CA}/openssl.cnf -extensions ${PURPOSE} -days 375 -notext -md sha256 -startdate 020501000000Z -in ${CA}/csr/${KEY_NAME}.csr.pem -out ${CA}/certs/${KEY_NAME}.cert.pem -passin pass:${PASSPHRASE} -batch -cert ${CA}/certs/ca-chain.cert.pem -key ${CA}/certs/private/${CA}.cert.pem
    chmod 444 ${CA}/certs/${KEY_NAME}.cert.pem
    openssl x509 -noout -text -in ${CA}/certs/${KEY_NAME}.cert.pem
    openssl verify -CAfile ${CA}/certs/ca-chain.cert.pem ${CA}/certs/${KEY_NAME}.cert.pem
    openssl x509 -in ${CA}/certs/${KEY_NAME}.cert.pem -purpose -noout

    cat ${CA}/certs/${KEY_NAME}.cert.pem ${CA}/private/${KEY_NAME}.key.pem > ${CA}/private/${KEY_NAME}.${CA}.cert
}

add () {
    KEY=${1}
    NEW_COMMONNAME=${2}
    PASSPHRASE=${3}
    CA=${4}
    PURPOSE=${5}

    create_key ${KEY} ${PASSPHRASE} ${CA}
    create_certificate_sign_request ${KEY} ${NEW_COMMONNAME} ${PASSPHRASE} ${CA}
    sign_certificate_sign_request ${KEY} ${PASSPHRASE} ${CA} ${PURPOSE}
}

#############################################################

if [ ! -f ${CA_DIR}/generated ]; then

    rm -rf ${CA_DIR}/*

    create_root_ca root1 pw_root1
    create_root_ca root2 pw_root2

    create_intermediate_ca intermediate1 pw_int1 root1 pw_root1
    create_intermediate_ca intermediate2 pw_int2 root2 pw_root2

    #   |filename       |CN             |passphrase |ca            |purpose
    add "telco0.public" "telco0.public" "pw_int1"  "intermediate1" "server_cert"
    add "client"        "client"        "pw_int1"  "intermediate1" "usr_cert"

    add "telco0.public" "telco0.public" "pw_int2"  "intermediate2" "server_cert"
    add "client"        "client"        "pw_int2"  "intermediate2" "usr_cert"

    add "telco0.public" "telco0.public" "pw_root2" "root2"         "server_cert"
    add "client"        "client"        "pw_root2" "root2"         "usr_cert"

    add "telco0.public" "telco0.public" "pw_root1" "root1"         "server_cert"
    add "client"        "client"        "pw_root1" "root1"         "usr_cert"

    add "telco1.public" "telco1.public" "pw_int1"  "intermediate1" "server_cert"

    add "telco1.public" "telco1.public" "pw_int2"  "intermediate2" "server_cert"

    add "telco1.public" "telco1.public" "pw_root2" "root2"         "server_cert"

    add "telco1.public" "telco1.public" "pw_root1" "root1"         "server_cert"

    touch ${CA_DIR}/generated
    touch ${CA_DIR}/upload
fi
