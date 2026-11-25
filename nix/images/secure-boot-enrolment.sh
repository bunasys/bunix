# The three files by which systemd-boot gives a machine's firmware the
# keys Secure Boot checks with (PK.auth, KEK.auth, db.auth): for a test
# machine, whose firmware comes with none (images/disk.nix,
# images/live.nix: secureBootEnrolment).  All three hold the one
# certificate, $certificate, and are signed with its key, $key: the
# development key, which is not secret.  With $microsoft_certificate, db
# holds Microsoft's UEFI CA as well, as every PC's has: what the shim of
# the live stick is signed by (images/live.nix).  A real machine's keys
# are its owner's to enrol.
#
# Each file is what the firmware's SetVariable takes for such a variable
# (UEFI 2.10, 8.2.6 and 32.4.1), an EFI_VARIABLE_AUTHENTICATION_2: a
# time, a signature over the variable's name, its vendor, its
# attributes, that time and its new value, and the value, which is a
# list of certificates (EFI_SIGNATURE_LIST).  There is no tool here that
# writes one, so the bytes are put together below, each field named as
# the specification has it.
#
# What the test machine shows of these: a firmware with no keys (setup
# mode) checks the signature on PK, which is its own certificate's, and
# takes db and KEK on their layout alone.  So the one signature tried is
# PK's; db's and KEK's are made the same way.
set -euo pipefail
cd /build

# a number as 2 or 4 bytes, lowest first, as EFI has its numbers
two_bytes() {
    printf "\\x$(printf %02x $(($1 & 255)))\\x$(printf %02x $(($1 >> 8 & 255)))"
}
four_bytes() {
    two_bytes $(($1 & 65535))
    two_bytes $(($1 >> 16 & 65535))
}
# An id as its 16 bytes.  EFI keeps the first three groups of digits
# lowest byte first, and the rest as written.
id_bytes() {
    local digits=${1//-/} place
    for place in 6 4 2 0 10 8 14 12 16 18 20 22 24 26 28 30; do
        printf "\\x${digits:place:2}"
    done
}
# a name as EFI has its text: two bytes a letter, and no end marked
name_bytes() {
    local name=$1 place
    for ((place = 0; place < ${#name}; place++)); do
        printf "${name:place:1}\\x00"
    done
}

# ids the specification gives
EFI_CERT_X509_GUID=a5c059a1-94e4-4aa7-87b5-ab155c2bf072        # a certificate in a list
EFI_CERT_TYPE_PKCS7_GUID=4aafd29d-68df-49ee-8aa9-347d375665a7  # a signature of this kind
EFI_GLOBAL_VARIABLE=8be4df61-93ca-11d2-aa0d-00e098032b8c       # PK's and KEK's vendor
EFI_IMAGE_SECURITY_DATABASE_GUID=d719b2cb-3d3a-4596-a3bc-dad00e67656f  # db's
# Whose entry this is in a list: any id will do.  This one is "bunix"
# and "testke" in ASCII, with the bits an id of this kind has.
owner=62756e69-7800-4000-8000-746573746b65

# A value: a list of one certificate (EFI_SIGNATURE_LIST), of the
# certificate in DER in the file named
#   certificate_list <file>
certificate_list() {
    local size
    size=$(stat -c %s $1)
    id_bytes $EFI_CERT_X509_GUID                 # SignatureType
    # SignatureListSize: these 28 bytes (type 16, three sizes of 4), and
    # the one entry
    four_bytes $((16 + 4 + 4 + 4 + 16 + size))
    four_bytes 0                                 # SignatureHeaderSize: none
    four_bytes $((16 + size))                    # SignatureSize: an owner and a certificate
    id_bytes $owner
    cat $1
}
openssl x509 -in $certificate -outform DER -out certificate.der
certificate_list certificate.der > value
# db's: a variable's value may be several lists, one after another
cp value db-value
if [ -n "${microsoft_certificate:-}" ]; then
    certificate_list $microsoft_certificate >> db-value
fi

# The time (EFI_TIME, 16 bytes): 1 January 2026, and nothing in the
# fields the firmware wants empty.  The firmware takes a variable only
# with a time later than the one it has, and a new machine has none.
{
    two_bytes 2026                      # Year
    printf '\x01\x01'                   # Month, Day
    printf '\x00\x00\x00\x00'           # Hour, Minute, Second, Pad1
    four_bytes 0                        # Nanosecond
    two_bytes 0                         # TimeZone
    printf '\x00\x00'                   # Daylight, Pad2
} > time

# non-volatile, for boot services and run time, and written only with a
# signature and a time: what such a variable has to be
attributes=$((0x1 | 0x2 | 0x4 | 0x20))

mkdir -p $out
enrolment_file() {
    local variable=$1 vendor=$2 value=$3
    {
        name_bytes $variable
        id_bytes $vendor
        four_bytes $attributes
        cat time $value
    } > signed-$variable
    # -noattr: the signature is of those bytes and nothing else, as the
    # firmware computes it
    openssl smime -sign -binary -noattr -md sha256 -outform DER \
        -signer $certificate -inkey $key -in signed-$variable -out signature-$variable
    signature_size=$(stat -c %s signature-$variable)
    {
        cat time                                 # TimeStamp
        # AuthInfo, a WIN_CERTIFICATE_UEFI_GUID: dwLength, the signature
        # with these 24 bytes (length 4, revision 2, type 2, id 16)
        four_bytes $((4 + 2 + 2 + 16 + signature_size))
        two_bytes 0x0200                         # wRevision: WIN_CERT_REVISION
        two_bytes 0x0ef1                         # wCertificateType: WIN_CERT_TYPE_EFI_GUID
        id_bytes $EFI_CERT_TYPE_PKCS7_GUID       # CertType
        cat signature-$variable $value           # CertData, then the variable's value
    } > $out/$variable.auth
}
# what may sign what is started; what may change that; and whose machine
# it is.  systemd-boot enrols them in that order: PK last, since setting
# it ends setup mode, and with it the taking of keys.
enrolment_file db $EFI_IMAGE_SECURITY_DATABASE_GUID db-value
enrolment_file KEK $EFI_GLOBAL_VARIABLE value
enrolment_file PK $EFI_GLOBAL_VARIABLE value
