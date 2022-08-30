#!/bin/bash
# Used for certificate issuance for client machines


# Greet the kind user
printf "\n ************************************************************************"
printf "\n Thank you for using BrianTheImpaler.com\'s Intermediate CA. This script\n will simplify the process of issuing a certificate to a new client\n machine using the openssl cli."
printf "\n ************************************************************************"
# Intake machine name
    printf "\n"
    read -p "Client Machine Name: (Please note, this is the machine name itself, `echo $'\nnot the FQDN of the machine):' echo $'\n> '`" machineVar
        # Create FQDN for later use in the cert common name
        fqdn='$machineVar'+'.briantheimpaler.com'
# Intake secrets
    printf "\n"
    # Read p12 pack password        
    read -sp "Generate a password for the client certificate .p12 pack: `echo $'\n> '` " p12PackPass
    printf "\n"
# Read Intermediate CA private key password
    printf "Please enter the password for the BrianTheImpaler.com \nIntermediate CA Private Key to allow it to sign the new certificate: \n" 
    read -sp "> " intCAKeyPass
printf "\n \n \n"

# Start doing some OpenSSL work
# Generate a shiny new private key for the client
openssl genrsa -out intermediate/private/$machineVar.key.pem 2048
    # Make the key secure
    chmod 400 intermediate/private/$machineVar.key.pem
printf "\n"
printf "Generated new private key!"
printf "\n"
# Generate a spankin' new CSR for the client
openssl req -config intermediate/openssl.cnf -key intermediate/private/$machineVar.key.pem -new -sha256 -out intermediate/csr/$machineVar.csr.pem -subj '/C=US/ST=Washington/L=Kent/O=briantheimpaler.com/CN=$fqdn/emailAddress=bhoglan@gmail.com'
    # Lets chmod the shit outta this file
    chmod 444 intermediate/csr/$machineVar.csr.pem
printf "\n"
printf "Generated the best CSR EVARRRR!"
printf "\n"
# Let's sign this bitch and generate the client's cert
openssl ca -config intermediate/openssl.cnf -batch -extensions usr_cert -days 3750 -notext -md sha256 -in intermediate/csr/$machineVar.csr.pem -out intermediate/certs/$machineVar.cert.pem -passin pass:$intCAKeyPass
    # You know the drill, chmod time!
    chmod 444 intermediate/certs/$machineVar.cert.pem
printf "\n"
printf "New client cert generated!"
printf "\n"
# Verify the new cert before we pack it up
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem intermediate/certs/$machineVar.cert.pem
printf "\n"
printf "The new client certificate matches the cert chain!"
printf "\n"

# Pack 'em all up in a .p12 file
openssl pkcs12 -export -in intermediate/certs/$machineVar.cert.pem -inkey intermediate/private/$machineVar.key.pem -certfile intermediate/certs/ca-chain-crl.pem -name $machineVar -out archive/$machineVar.p12 -passout pass:$p12PackPass

# Make it easy for the user to find the new file
printf "You can find the new client certificate pack in /root/ca/archive/$machineVar.p12 \n"

# Cleanup time
#rm tmp/intCAKeyPassFile
#rm tmp/p12PackPassFile
#rm tmp/pvtKeyPassFile





