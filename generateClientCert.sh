#!/bin/bash
# Used for certificate issuance for client machines

# Set will cause bash to handle the script in better ways. Primarily it will cause the script
# to exit if any of the commands encounters an error, instead of continuing to execute the 
# remaining commands. For a little fun, uncomment the -x to turn on debugging mode.
set -Eeuo pipefail #-x

trap cleanup SIGINT SIGTERM ERR EXIT

# Sets the script's location for relativity's sake.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

####Generate a nice little help flag for the user####
usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]

-h, --help		Print this dialogue.
-v, --verbose	        Print ALL the output from the script (debug mode).

This script is used to help automate client machine certificate generation 
using the Intermediate CA on this box. It runs 4 openssl commands to: generate 
a new private key, generate a csr, sign the csr and generate the certificate, 
and finally package the genrated files as a .p12 file that is password protected. 
The output of this file is a .p12 certificate bundle including the cert chain for the CA.

Requirements:
  - You need the machine name for which you're generating the certificate.
  - You need a STRONG password for the .p12 package. You must store this 
    password somewhere safe. You will need it to unlock the file when installing 
    the certificate and key on the client machine. Additionally, this password 
    will decrypt the .p12 package leaving the private key in plaintext.
  - You will need the password to decrypt the private key for the Intermediate CA 
    to allow it to sign the new client certificate.

EOF
}
####End of help section####

# Cleanup will watch for abnormal exits and attempt to clean up any mess we've made
# (deleting temp files, maybe?)
cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here. Figure out how to run the revoke script if it makes it far enough through
  # this script to get the certificate signed and generated. Simply deleting the generated cert will
  # cause problems when you try to run the script again and generate another cert for the same 
  # client machine.
}

# OMG colors. Gonna RGB the shit outta this thing.
setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

# Parse parameters given at the shell
parse_params() {
  # default values of variables set from params
  flag=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -f | --flag) flag=1 ;; # example flag
    -p | --param) # example named parameter
      param="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done


  args=("$@")

  # check required params and arguments
  [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

parse_params "$@"
setup_colors

# This script depends on the openssl package which should already be installed, but we'll check 
# for that anyway and end the script if we get a non-zero exit code from the openssl command
_=$(command -v openssl);
if [ "$?" != "0" ]; then
  printf -- "You don\'t seem to have openssl installed.\n";
  printf -- "Get it by downloading and compiling from source: https://www.openssl.org/source/ \n";
  printf -- "This will require the following packages to be installed on Ubuntu:\n";
  printf -- "sudo apt install build-essential checkinstall zlib1g-dev\n";
  printf -- "Exiting with code 127 (command not found)\n";
  exit 127;
fi;

# Greet the kind user
printf "\n ************************************************************************"
printf "\n Thank you for using BrianTheImpaler.com\'s Intermediate CA. This script\n will simplify the process of issuing a certificate to a new client\n machine using the openssl cli."
printf "\n ************************************************************************"
# Intake machine name
    # This is one method of reading the variable. It's a little fucky because 'read' doesn't like
    # newline characters. So you have to echo the newline in. Oddly enough it won't actually echo
    # the character without the second \b (backspace) character to "give it something to do"
    printf "\n"
    printf "Client Machine Name: (Please note, this is the machine name itself, \nnot the FQDN of the machine):"
    read -sp "`echo $'\n> '`" machineVar
        # Create FQDN for later use in the cert common name
        fqdn='$machineVar'+'.briantheimpaler.com'
# Intake secrets
    printf "\n"
    # Read p12 pack password        
    read -sp "Generate a password for the client certificate .p12 pack: `echo $'\n> '` " p12PackPass
    printf "\n"
# Read Intermediate CA private key password
    # This is the other method of reading the variable. This method uses printf to nicely print the
    # text. Then we use read -sp to read in the password.
    printf "Please enter the password for the BrianTheImpaler.com \nIntermediate CA Private Key to allow it to sign the new certificate: \n" 
    read -sp "> " intCAKeyPass
    ##!!TODO - write this var to a file so the openssl command can use that for the -passin value
    ##!! This is a safer way to pass the password since the file contents (the password)
    ##!! won't be shown on a 'ps' command.
printf "\n \n \n"

# Start doing some OpenSSL work
# Generate a shiny new private key for the client
openssl genrsa -out intermediate/private/$machineVar.key.pem 2048
    # Make the key secure
    chmod 400 intermediate/private/$machineVar.key.pem
printf "\n"
# Add a unicode green check mark symbol to the beginning and end of the output (\U2705)
# Add some green to our success messages (\033[32m followed by \033[0m)
printf "\U2705\033[32m SUCCESS: Generated new private key!\033[0m\U2705"
printf "\n"
# Generate a spankin' new CSR for the client
openssl req -config intermediate/openssl.cnf -key intermediate/private/$machineVar.key.pem -new -sha256 -out intermediate/csr/$machineVar.csr.pem -subj '/C=US/ST=Washington/L=Kent/O=briantheimpaler.com/CN=$fqdn/emailAddress=bhoglan@gmail.com'
    # Lets chmod the shit outta this file
    chmod 444 intermediate/csr/$machineVar.csr.pem
printf "\n"
printf "\U2705\033[32m SUCCESS: Generated the best CSR EVARRRR!\033[0m\U2705"
printf "\n"
# Let's sign this bitch and generate the client's cert
openssl ca -config intermediate/openssl.cnf -batch -extensions usr_cert -days 3750 -notext -md sha256 -in intermediate/csr/$machineVar.csr.pem -out intermediate/certs/$machineVar.cert.pem -passin pass:$intCAKeyPass
    # You know the drill, chmod time!
    chmod 444 intermediate/certs/$machineVar.cert.pem
printf "\n"
printf "\U2705\033[32m SUCCESS: New client cert generated!\033[0m\U2705"
printf "\n"
# Verify the new cert before we pack it up
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem intermediate/certs/$machineVar.cert.pem
printf "\n"
printf "\U2705\033[32m SUCCESS: The new client certificate matches the cert chain!\033[0m\U2705"
printf "\n"

# Pack 'em all up in a .p12 file
openssl pkcs12 -export -in intermediate/certs/$machineVar.cert.pem -inkey intermediate/private/$machineVar.key.pem -certfile intermediate/certs/ca-chain-crl.pem -name $machineVar -out archive/$machineVar.p12 -passout pass:$p12PackPass

# Make it easy for the user to find the new file
printf "\U1F50D\033[33m You can find the new client certificate pack in /root/ca/archive/$machineVar.p12\033[0m\U1F50E\n"

# Whelp, we've reached the end of the script, what's left to do? Oh yeah, msg handling. 
# msg is for errros as it outputs to stderr instead of stdout. Plus it handles colors.
msg "${RED}Read parameters:${NOFORMAT}"
msg "- flag: ${flag}"
msg "- param: ${param}"
msg "- arguments: ${args[*]-}"
