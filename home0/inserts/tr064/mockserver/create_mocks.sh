#!/bin/sh

DATA_DIR="default"
#set -x
VERBOSE="no"

show_help() {
    echo "This is ${0}, to create a local TR-064 mock for testing."
    echo ""
    echo "  You can define a profile with --profile=<NAME>. The profile, if not"
    echo "  being build in, will be represented by a directory. You can copy"
    echo "  the directory to a new one, change the content of the files to the"
    echo "  desired ones and use the new directory as a new profile."
    echo "  A not existing profile will be created as directory and filled"
    echo "  with default values."
    echo "  You can use as may profiles you like, they are applied in the"
    echo "  specified order and will overwrite settings."
    echo ""
    echo "  Build in profiles:"
    echo "     default -> Speedport Smart 3"
    echo "                    * DEVICE_SpeedportSmart3"
    echo "                    * TR181"
    echo "                    * DATASET_SP_17a"
    echo ""
    echo "     DEVICE_SpeedportSmart3 (profile 17a) \\"
    echo "     DEVICE_Fritz7590       (profile 30a)  \\"
    echo "     DEVICE_Fritz7490       (profile 17a)   }-> mocking this device"
    echo "     DEVICE_Fritz7490_without_support      /"
    echo "     DEVICE_GenericRouter                 /"
    echo "     TR181   -> responding to GetParameterValues for"
    echo "                Device.DSL.Line.1.TestParams. with 200 and data"
    echo "     TR098   -> responding to X_GENERIC_GetVDSLInfo with"
    echo "                HTTP 200 and data"
    echo "     200 -> will respond with HTTP 200 and data"
    echo "     500 -> will respond with HTTP 500 error 401 Invalid Action"
    echo "     DATASET_SP_17a -> data set from speedport (profile 17a)"
    echo "     DATASET_FB_17a -> data set from fritzbox  (profile 17a)"
    echo "     DATASET_FB_30a -> data set from fritzbox  (profile 30a)"
    echo ""
    echo "  The mock can then be found using SSDP and will serve the data from"
    echo "  the selected profile directory."
    echo "  Also the IP address to be announced can be set by --IP=<IP>,"
    echo "  default is 127.0.0.1"
    echo ""
}

copy_mocks() {
  if [ -f "/opt/${DATA_DIR}/XML_FILES" ]; then
    XML_FILES=$(cat "/opt/${DATA_DIR}/XML_FILES")
    for FILE in $XML_FILES; do
      if [ -f "/opt/$FILE" ]; then
        local IP=$(cat "/opt/MOCK_IP_ADDRESS")
        local PORT=$(cat "/opt/${DATA_DIR}/PORT")
        if [ -f "/opt/${DATA_DIR}/PATH" ]; then 
          local URL_PATH=$(cat "/opt/${DATA_DIR}/PATH")
        else
          local URL_PATH=''
        fi
        cp "/opt/$FILE" "/opt/$FILE.work"
        sed -i "s#\[MOCKED_IP\]#${IP}#g" "/opt/$FILE.work"
        sed -i "s#\[MOCKED_PORT\]#${PORT}#g" "/opt/$FILE.work"
        sed -i "s#\[MOCKED_PATH\]#${URL_PATH}#g" "/opt/$FILE.work"
        local LEN=$(stat --format=%s "/opt/$FILE".work)
        mkdir -p "/opt/mocks/$FILE"
        echo -e "HTTP/1.1 200 OK\r\nConnection: Close\r\nContent-Length: ${LEN}\r\nContent-Type: text/xml\r\n\r" > "/opt/mocks/$FILE/GET.mock"
        cat "/opt/$FILE.work" >> "/opt/mocks/$FILE/GET.mock"
        rm "/opt/$FILE.work"
      else
        echo "File $FILE is not available."
      fi
    done
  fi
}

generate_mock() {
  local ADD_PREFIX="$1"
  local REQUEST="$2"
  local RESPONSE="$3"
  # generate mocks in the directory mocks
  mkdir -p mocks
  cd mocks

  #generate the directory structure for the mock
  export IFS="/"
  local CURRENT_STEP=""
  local TO_CREATE=""
  for PART in ${REQUEST}; do
      if [ "${PART}" = "" ]; then
          continue;
      else
        CURRENT_STEP="${ADD_PREFIX}${PART}"
        ADD_PREFIX=""
      fi

      if [ "${TO_CREATE}" = "" ]; then
        TO_CREATE="${CURRENT_STEP}"
      else
        mkdir -p "${TO_CREATE}"
        cd "${TO_CREATE}"
        TO_CREATE="${CURRENT_STEP}"
      fi
    done

    #copy the response to be mocked to the mock
    cp "${RESPONSE}" "${TO_CREATE}.mock"

    cd "/opt"
}

generate_response() {
  local IN_FILE="$1"
  local OUT_FILE="$2"
  rm -f "${OUT_FILE}"
  cp "$IN_FILE" "$OUT_FILE"
  for FILE in /opt/${DATA_DIR}/*; do
    local MOCK_NAME=$(basename "$FILE")
    local MOCKED_DATA_CONTENT="$(cat /opt/${DATA_DIR}/${MOCK_NAME})"
    sed -i "s#\[MOCKED_${MOCK_NAME}\]#${MOCKED_DATA_CONTENT}#g" "$OUT_FILE"
  done
  local LINE=$(($(grep "^$" -n "$OUT_FILE" | cut -d':' -f1)+1))
  local LEN="$(tail -n+$LINE "$OUT_FILE" | wc -c)"
  sed -i "s#\[CALC_LEN\]#${LEN}#" "$OUT_FILE"
}

set_profile() {
  cd "/opt"
  mkdir -p "${DATA_DIR}"
  cd "${DATA_DIR}"

  case "${1}" in
    DATASET_SP_17a)
      printf "8" > SNRGds;
      printf "8" > SNRGus;
      printf "255,255,255,255,255,255,255,255,255,168,170,172,173,174,175,176,177,177,178,178,178,179,179,179,180,180,180,180,180,181,180,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,182,182,181,182,181,182,181,181,182,182,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,181,180,180,180,180,180,255,180,180,179,179,179,179,179,178,178,177,177,177,177,177,177,177,177,176,176,175,174,172,169,167,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,165,166,168,169,169,169,169,169,169,169,169,169,169,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,169,169,169,169,169,169,168,167,167,166,167,168,168,169,169,169,169,169,169,169,169,169,169,169,167,167,167,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,168,167,168,168,255,168,167,168,168,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,154,153,154,153,154,153,152,153,153,153,153,154,153,153,154,154,155,154,154,156,156,156,156,155,156,156,157,157,157,157,157,157,157,158,158,158,158,158,157,156,155,155,154,155,154,154,154,154,154,154,155,154,155,155,156,156,157,157,157,157,156,157,157,157,157,157,157,157,156,157,157,156,157,156,156,156,156,156,156,157,156,156,156,156,156,156,157,157,156,156,157,156,156,156,156,156,156,156,157,156,156,156,156,156,156,156,156,155,155,156,156,156,155,156,155,155,156,156,156,155,155,155,156,156,156,155,156,155,155,155,155,155,156,155,155,156,155,155,155,155,155,155,154,155,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255" > SNRpsds;
      printf "255,255,255,064,144,163,164,145,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,064,182,180,181,180,178,178,178,177,177,176,176,176,176,175,172,173,175,175,172,175,175,172,173,174,175,175,175,174,175,173,173,172,172,173,173,172,172,170,171,172,064,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,064,176,166,172,171,174,175,177,180,181,181,181,181,181,177,171,169,166,168,155,168,170,165,164,167,158,162,165,167,164,157,164,170,163,170,168,157,169,171,169,173,173,178,178,178,179,179,179,177,169,171,168,167,158,170,166,169,172,160,160,164,165,165,165,160,157,165,161,163,160,150,158,163,162,162,160,158,163,166,174,173,174,173,172,169,162,159,150,163,159,160,163,153,151,154,159,159,156,150,157,064,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255" > SNRpsus;
      printf "0" > CRCErrors;
      printf "Up" > LinkStatus;
      printf "17a" > CurrentProfile;
      printf "139815" > DownstreamMaxBitRate;
      printf "55351" > UpstreamMaxBitRate;
      printf "102345" > DownstreamCurrRate;
      printf "41434" > UpstreamCurrRate;
      printf "176" > DownstreamNoiseMargin;
      printf "199" > UpstreamNoiseMargin;
      printf "" > length;
      printf "256" > SNRMTds;
      printf "256" > SNRMTus;
      printf "17,47,47,0,0" > LATNds;
      printf "7,47,11,0,0" > LATNus;
      printf "0" > FECErrors;
      printf "G.993.2_Annex_B" > StandardUsed;
      ;;
    DATASET_FB_17a)
      printf "8" > SNRGds;
      printf "1" > SNRGus;
      printf "0,0,0,0,78,96,100,0,0,102,104,104,106,106,108,108,108,110,110,110,110,110,110,110,110,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,114,112,112,112,112,112,112,112,112,112,114,114,112,114,112,112,114,112,114,114,112,112,112,114,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,110,112,110,110,110,110,108,106,106,104,0,0,0,120,118,118,118,88,88,88,88,88,88,118,116,114,116,114,114,114,116,114,114,114,114,112,114,114,114,114,114,112,114,112,110,110,112,112,110,112,110,110,112,0,0,102,102,104,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,104,106,106,106,104,106,106,106,106,104,106,106,106,106,106,106,106,106,106,104,106,104,104,106,106,106,106,106,106,106,106,106,106,106,106,106,106,106,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,104,102,0,0,0,118,110,112,114,114,116,112,116,118,116,118,116,118,118,114,112,106,102,92,102,112,114,110,112,92,112,112,110,114,92,106,114,112,112,112,106,110,116,116,114,114,116,116,116,118,118,116,116,114,112,112,114,108,114,112,114,112,110,108,114,114,106,112,98,110,100,110,102,106,98,108,106,110,106,106,108,108,108,110,110,110,110,110,110,108,106,96,108,108,104,108,104,94,104,104,96,104,100,102,0,0,0,92,92,92,92,92,92,92,92,92,92,92,92,90,92,92,92,94,92,92,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,92,94,92,92,92,92,92,92,92,92,92,92,92,92,92,92,94,94,94,94,94,94,94,94,94,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,90,90,90,90,90,90,90,90,90,90,90,90,88,90,90,90,90,88,90,90,90,90,90,88,90,90,90,90,90,88,88,88,88,88,88,88,88,88,88,88,88,86,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0" > SNRpsds;
      printf "" > SNRpsus;
      printf "62" > CRCErrors;
      printf "Up" > LinkStatus;
      printf "17a" > CurrentProfile;
      printf "143376" > DownstreamMaxBitRate;
      printf "62153" > UpstreamMaxBitRate;
      printf "103887" > DownstreamCurrRate;
      printf "41434" > UpstreamCurrRate;
      printf "170" > DownstreamNoiseMargin;
      printf "200" > UpstreamNoiseMargin;
      printf "" > length;
      printf "512" > SNRMTds;
      printf "0" > SNRMTus;
      printf "2,4,4,127,127" > LATNds;
      printf "0,3,0,127,127" > LATNus;
      printf "0" > FECErrors;
      printf "VDSL" > StandardUsed;
      ;;
    DATASET_FB_30a)
      printf "8" > SNRGds;
      printf "1" > SNRGus;
      printf "0,0,0,0,0,80,86,89,93,95,97,99,100,100,102,102,102,104,104,105,104,104,106,106,106,106,106,107,106,107,108,108,108,108,108,108,108,108,108,108,108,108,108,109,108,108,109,108,108,108,110,108,109,0,0,64,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,64,0,110,110,110,110,111,110,111,111,111,112,111,112,111,111,110,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,112,0,0,63,125,126,126,125,125,125,125,124,124,124,124,124,124,124,124,124,124,124,124,124,124,124,124,124,124,123,123,123,124,123,123,123,124,124,123,124,123,123,122,122,122,122,122,122,122,122,122,122,0,0,113,114,114,114,114,114,114,114,114,114,113,113,113,113,114,113,114,113,113,114,113,113,113,114,114,114,114,114,113,114,114,113,113,113,113,113,114,114,113,112,113,113,112,112,112,113,114,113,113,114,113,113,112,114,112,113,112,113,112,113,112,113,112,113,114,113,113,114,114,114,114,114,114,114,114,114,114,114,114,113,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0" > SNRpsds;
      printf "" > SNRpsus;
      printf "0" > CRCErrors;
      printf "Up" > LinkStatus;
      printf "30a" > CurrentProfile;
      printf "161792" > DownstreamMaxBitRate;
      printf "62081" > UpstreamMaxBitRate;
      printf "149998" > DownstreamCurrRate;
      printf "58162" > UpstreamCurrRate;
      printf "90" > DownstreamNoiseMargin;
      printf "160" > UpstreamNoiseMargin;
      printf "" > length;
      printf "512" > SNRMTds;
      printf "0" > SNRMTus;
      printf "1,1,0,127,127" > LATNds;
      printf "127,0,0,127,127" > LATNus;
      printf "0" > FECErrors;
      printf "VDSL" > StandardUsed;
      ;;
    TR181)
      printf "TR181" > PROFILE
      printf "200" > RESPONSE
      printf "GetParameterValues" > REQUEST_KEY
      ;;
    TR098)
      printf "TR098" > PROFILE
      printf "200" > RESPONSE
      printf "X_GENERIC_GetVDSLInfo" > REQUEST_KEY
      ;;
    200)
      printf "200" > RESPONSE
      ;;
    500)
      printf "500" > RESPONSE
      ;;
    SpeedportSmart3)
      printf "Speedport Smart 3 010137.3.5.000.0" > SERVER
      printf "description.xml" > LOCATION
      printf 'cwmp="urn:telekom-de:device:TO_InternetGatewayDevice:2"' > xmlns
      printf "urn:telekom-de:device:TO_InternetGatewayDevice:2" > ST
      printf "5438" > PORT
      printf 'description.xml' > XML_FILES
      printf 'GetParameterValues' > POST_ACT
      printf '' > PATH
      ;;
    SpeedportW922V)
      printf "DTW922V UPnP/1.0 Speedport W 922V 01013203.01.002" > SERVER
      printf "tr64_igd.xml" > LOCATION
      printf 'cwmp="urn:dslforum-org:device:InternetGatewayDevice:1"' > xmlns
      printf "urn:dslforum-org:device:InternetGatewayDevice:1" > ST
      printf "5438" > PORT
      printf 'tr64_igd.xml tr64_igd_wdic.xml' > XML_FILES
      printf 'GetParameterValues' > POST_ACT
      printf '' > PATH
      ;;
    Fritz7590)
      printf "FRITZ!Box 7590 UPnP/1.0 AVM FRITZ!Box 7590 154.07.19" > SERVER
      printf "tr64desc.xml" > LOCATION
      printf 'u="urn:dslforum-org:service:WANDSLInterfaceConfig:1"' > xmlns
      printf "urn:dslforum-org:service:InternetGatewayDevice:1" > ST
      printf "X_AVM-DE_GetDSLInfo" > REQUEST_KEY
      printf "49000" > PORT
      printf 'tr64desc.xml wandslifconfigSCPD.xml' > XML_FILES
      printf 'upnp/control/wandslifconfig1' > PATH
      ;;
    Fritz7490)
      printf "FRITZ!Box 7490 UPnP/1.0 AVM FRITZ!Box 7490 113.07.21" > SERVER
      printf "tr64desc.xml" > LOCATION
      printf 'u="urn:dslforum-org:service:WANDSLInterfaceConfig:1"' > xmlns
      printf "urn:dslforum-org:service:InternetGatewayDevice:1" > ST
      printf "X_AVM-DE_GetDSLInfo" > REQUEST_KEY
      printf "49000" > PORT
      printf 'tr64desc.xml wandslifconfigSCPD.xml' > XML_FILES
      printf 'upnp/control/wandslifconfig1' > PATH
      ;;
    GenericRouter)
      printf "Generic Router UPnP/1.0 generic router 1.1.0" > SERVER
      printf "tr064gen.xml" > LOCATION
      printf 'u="urn:schemas-upnp-org:service:ConfigurationManagement:2"' > xmlns
      printf "urn:schemas-upnp-org:service:ConfigurationManagement:2" > ST
      printf "49001" > PORT
      printf 'tr064gen.xml UPnPdescription.xml' > XML_FILES
      printf 'GetSupportedDataModels GetSupportedParameters GetValues' > POST_ACT
      printf '' > PATH
      ;;
    DEVICE_SpeedportSmart3)
      set_profile DATASET_SP_17a
      set_profile TR181
      set_profile SpeedportSmart3
      ;;
    DEVICE_Fritz7590)
      set_profile DATASET_FB_30a
      set_profile TR098
      set_profile Fritz7590
      ;;
    DEVICE_Fritz7490)
      set_profile DATASET_FB_17a
      set_profile TR098
      set_profile Fritz7490
      ;;
    DEVICE_Fritz7490_without_support)
      set_profile TR098
      set_profile 500
      set_profile Fritz7490
      ;;
    DEVICE_GenericRouter)
      set_profile DATASET_SP_17a
      set_profile TR181
      set_profile GenericRouter
      ;;
    *)
      DATA_DIR="${1}"
      ;;
  esac
  cd "/opt"
}

generate_mocks() {
  rm -rf "mocks"

  if [ ! -f "/opt/${DATA_DIR}/PATH" ]; then
    touch "/opt/${DATA_DIR}/PATH"
  fi

  copy_mocks

  local MOCK_PATH="$(cat "/opt/${DATA_DIR}/PATH")"
  if [ -n "$MOCK_PATH" ]; then
    echo "$MOCK_PATH " | grep -q '/$' || MOCK_PATH="${MOCK_PATH}/"
  fi

  case $(cat /opt/${DATA_DIR}/PROFILE) in
    TR181)
      if [ -f "/opt/${DATA_DIR}/POST_ACT" ]; then
        POST_ACT=$(cat "/opt/${DATA_DIR}/POST_ACT")
      else
        POST_ACT=GetParameterValues
      fi
      for I in $POST_ACT; do
        generate_response "/opt/$(cat "/opt/${DATA_DIR}/PROFILE")_${I}.$(cat "/opt/${DATA_DIR}/RESPONSE")" "/opt/response"
        cp "/opt/SOAP_${I}.request" "/opt/SOAP.request.work"
        local XMLNS_CONTENT="$(cat /opt/${DATA_DIR}/xmlns)"
        sed -i "s#\[MOCKED_xmlns\]#${XMLNS_CONTENT}#g" "/opt/SOAP.request.work"
        local SOAP_REQUEST="$(cat "/opt/SOAP.request.work")"
        rm "/opt/SOAP.request.work"
        generate_mock "${MOCK_PATH}POST--" "${SOAP_REQUEST}" "/opt/response"
      done
      ;;
    TR098)
      generate_response "/opt/$(cat /opt/${DATA_DIR}/PROFILE).$(cat /opt/${DATA_DIR}/RESPONSE)" "/opt/response"
      generate_mock "" "${MOCK_PATH}POST" "/opt/response"
      ;;
  esac
  rm "/opt/response"

  generate_mock "" "alive-response/GET" "/opt/alive.response"
}

check_mocking_services() {
  cd "/opt"
  local RESTART_SSPD="no"
  for FILE in SERVER ST LOCATION PORT; do
    if [ ! -f "/opt/${DATA_DIR}/${FILE}" ]; then
      echo "File: ${DATA_DIR}/${FILE} not found!"
      echo "ERROR: Cannot restart mock server!"
      return
    fi
    local MOCK_NAME=$(basename "${FILE}")
    local MOCKED_DATA_OLD_CONTENT="$(cat .${MOCK_NAME}_OLD_CONTENT)"
    local MOCKED_DATA_CONTENT="$(cat ${DATA_DIR}/${MOCK_NAME})"
    echo "${MOCKED_DATA_CONTENT}">.${MOCK_NAME}_OLD_CONTENT
    if [ "${MOCKED_DATA_OLD_CONTENT}" != "${MOCKED_DATA_CONTENT}" ]; then
        RESTART_SSPD="yes"
    fi
  done
  if [ "${RESTART_SSPD}" != "no" ]; then
    pkill node
    python3 "/opt/mockserver_handler.py" "--log=/opt/mock.log" "--port=$(cat "/opt/${DATA_DIR}/PORT")"
    pkill python3 || echo "No SSDP mock killed ..."
    python3 ./ssdp_mock.py --logfile=./ssdp.log --st="$(cat ${DATA_DIR}/ST)" --server-name="$(cat ${DATA_DIR}/SERVER)"\
      --location-ip=$(cat "/opt/MOCK_IP_ADDRESS") --location-port=$(cat "/opt/${DATA_DIR}/PORT") --location-file=$(cat "/opt/${DATA_DIR}/LOCATION")&
    echo "### ok"
  fi
}

read_commandline() {
    while :; do
	case $1 in
            -h|-\?|--help)
		show_help
		exit
		;;
            -p|--profile)
		if [ -n "$2" ]; then
                     set_profile $2
                    shift
		else
                    printf 'ERROR: "-p" or "--profile" requires a non-empty option argument.\n' >&2
                    exit 1
		fi
		;;
            --profile=?*)
		set_profile ${1#*=}
		;;
            --profile=)
            printf 'ERROR: "--profile" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
            --IP=?*)
		printf "${1#*=}">"/opt/MOCK_IP_ADDRESS"
		;;
            --verbose=?*)
		VERBOSE=${1#*=}
		;;
            -v|--verbose)
		if [ -n "$2" ]; then
                     VERBOSE=${2}
                    shift
		else
                    printf 'ERROR: "-v" or "--verbose" requires a non-empty option argument.\n' >&2
                    exit 1
		fi
		;;
            --)
		shift
		break
		;;
            -?*)
		printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;
            *)
		break
	esac

	shift
    done
}

################################################################################
#
# mainline
#
################################################################################
if [ ! -d "/opt/${DATA_DIR}" ]; then
	rm .*_OLD_CONTENT
fi

read_commandline ${@}

if [ -d "/opt/${DATA_DIR}" ]; then
    if [ "${VERBOSE}" != "no" ]; then
	echo "Imported data from /opt/${DATA_DIR}:"
	for FILE in /opt/${DATA_DIR}/*; do
	    MOCKED_DATA_CHUNK=$(basename "${FILE}")
	    echo "  ${MOCKED_DATA_CHUNK}=$(cat /opt/${DATA_DIR}/${MOCKED_DATA_CHUNK})"
	done
    fi
else
    echo "Using dataset 1 with device \"Speedport Smart3\" at ${DATA_DIR}..."
    set_profile DEVICE_SpeedportSmart3
fi

generate_mocks

check_mocking_services
