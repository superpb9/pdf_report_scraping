#!/bin/bash

# This script is to grep the key info from PDF
# Pre-requisite: poppler-utils, mutt, ssmtp( /etc/ssmtp/ssmtp.conf) 

CURRENT_DIR="$(pwd)"
FILE_LIST="$(ls -la | grep -E '*[.][pP][dD][fF]$')"
BANNER+="$(echo -e "#######################################\n--- Customer XX Vulnerability Report Viewer ---\n------  Author: Patrick Dong - Sep 2018  ------\n#######################################")"

# Define a usage() function 
usage (){
  #echo "Usage: ${0} [-e RECEIVER]" >&2
  echo "Usage: ${0} [-e]" >&2
  echo "The script will automatically process any PDF files under the current directory, which is ${CURRENT_DIR}." >&2 
  # echo "    -e   Archieve PDF files and send an email." >&2
  echo "    -e   Archieve PDF files." >&2
  exit 1
}

# Allow user to specify the following options:
# Any other option will cause the script to display a usage statement
# while getopts e: OPTION
while getopts e OPTION
do
  case  ${OPTION} in
    # e) SEND_EMAIL='true' RECEIVER="${OPTARG}" ;; 
    e) SEND_EMAIL='true' ;; 
    ?) usage ;;
  esac
done

# Ingore all the optional arguments
# Remove the options while leaving the remaining arguments.
# OPTIND is set to the index of the first non-option argument, and name is set to ?
shift "$(( OPTIND - 1 ))"

# If unable to matching any file with extention of ".pdf", ".PDF", etc.
if [[ "${FILE_LIST}" = "" ]]
then
  usage
  exit 1
fi

# Using awk to exclude Columns 1 to Columns 8
# each PDF file name will be saved into the below variable  
FILE_NAME="$(echo "${FILE_LIST}" | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | sed 's/^[ \t]*//')"

# Display script banner
echo "${BANNER}"
echo ""
# Declare an array ARR_LIST for archiving purposes
# Declare an array EMAIL_CONTENT used for email sending 
declare -a ARR_LIST
declare -a EMAIL_CONTENT
EMAIL_CONTENT+=("${BANNER}")
EMAIL_CONTENT+=("")

# Using WHILE Loop to process all the PDF files
while read line
do
  # Display the processing file name
  NOW_PROCESSING=("Now processing ${line} ...")
  echo "${NOW_PROCESSING}"
  EMAIL_CONTENT+=("${NOW_PROCESSING}")
  # Report generating date checking 
  # SERVER_NAME_IP=$(pdftotext -f 1 -l 1 "${line}" - | grep '(')
  IRRELEVANT=$(pdftotext "${line}" - | grep 'Audit Report' | awk -F 'Audit Report ' '{print $1}')
  AUDITED=$(pdftotext "${line}" - | grep 'Audited on' | awk -F 'on ' '{print $2}')
  REPORTED=$(pdftotext "${line}" - | grep 'Reported on' | awk -F 'on ' '{print $2}')
  if [[ "${IRRELEVANT}" = *"Audit Report"* ]]
  then
    echo "Info: This PDF does not look like a valid Remediation Plan." 
    echo ""
    continue
  fi
  # If it's an invaild PDF
  if [[ "${AUDITED}" = "" && "${REPORTED}" = "" ]]
  then
    TEMP1=$(echo "Whoops, looks like it is not a valid vulnerability report")
    echo "${TEMP1}"
    echo ""
    EMAIL_CONTENT+=("${TEMP1}")
    EMAIL_CONTENT+=("$(echo "")")
  fi
  # If 'audited date' equals to 'reported date'
  if [[ "${AUDITED}" = *"${REPORTED}"* && "${AUDITED}" != "" ]]
  then
    ARR_LIST+=("${line}")
    TEMP2=$(pdftotext "${line}" - | grep -E 'vulnerability was discovered|vulnerabilities were discovered' | cut -b 4-)
    if [[ ${TEMP2} = "" ]]
    then
	echo "Info: No vulnerabilitis found in this PDF Report."
        echo ""
    else 
        echo "${TEMP2}"
        echo ""
        EMAIL_CONTENT+=("${TEMP2}")
        EMAIL_CONTENT+=("$(echo "")")
        continue
    fi
  fi
  # If 'audited date' does not equal to 'reported date'
  if [[ "${AUDITED}" != "${REPORTED}" && "${AUDITED}" != "" ]]
  then 
    ARR_LIST+=("${line}")
    TEMP3_1=$(echo "Info: Audited Date does not equal to Reported Date.") 
    TEMP3_2=$(echo "Audited on ${AUDITED}")
    TEMP3_3=$(echo "Reported on ${REPORTED}")
    echo "${TEMP3_1}"
    echo "${TEMP3_2}"
    echo "${TEMP3_3}"
    echo ""
    EMAIL_CONTENT+=("${TEMP3_1}")
    EMAIL_CONTENT+=("${TEMP3_2}")
    EMAIL_CONTENT+=("${TEMP3_3}")
    EMAIL_CONTENT+=("$(echo "")")
  fi
done <<< "$(echo -e "${FILE_NAME}")"

# Archieve and remove the PDFs in which Audited Date equals Reported Date
# FILE Naming Convention: XXX-$(date +%d%m%y).tar.gz
if [[ ${SEND_EMAIL} == "true" && "${ARR_LIST}" != "" ]]
then
  # Archeving PDF files first
  echo "The following PDFs have been archieved ..."
  printf '%s\n' "${ARR_LIST[@]}"
  echo ""
  tar -czf XXX-$(date +%d%m%y).tar.gz "${ARR_LIST[@]}" --remove-files
  # tar -czf XXX-$(date +%d%m%y).tar.gz "${ARR_LIST[@]}"
  # If there's an error when archiving PDF files 
  if [[ "${?}" -ne 0 ]]
  then
    echo "Whoops, something wrong with the archieved file ..." >&2
    exit 1
  fi
  ## Send an email
  #echo "Sending an email to ${RECEIVER} ..."
  #printf '%s\n' "${EMAIL_CONTENT[@]}" | mutt -s "XXX-Report" "${RECEIVER}" -a XXX-$(date +%d%m%y).tar.gz 
  #if [[ "${?}" -eq 0 ]]
  #then
  #  echo "Email successfully sent out ..."
  #  exit 0
  #fi
fi

exit 0
