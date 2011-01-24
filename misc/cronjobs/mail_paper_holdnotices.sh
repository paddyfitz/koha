#!/bin/bash
#requires: basename,date,md5sum,sed,sendmail,uuencode
function fappend {
    echo "$2">>$1;
}
YYYYMMDD=`date +%Y-%m-%d`
#YYYYMMDD=2011-01-21
file="holdnotices-$YYYYMMDD"

# CHANGE THESE
TOEMAIL="Geraldine.Kane@halton.gov.uk,Joanne.Russell@halton.gov.uk,Ruth.Smith@halton.gov.uk,haltonlea.library@halton.gov.uk";
#TOEMAIL="jonathan.field@ptfs-europe.com";
FREMAIL="haltonlea.library@halton.gov.uk";
SUBJECT="Daily Print Hold Notices - $YYYYMMDD";
MSGBODY="Attached are the Daily Print Hold Notices";
ATTACHMENT="/home/koha/kohaclone/koha-tmpl/intranet-tmpl/notices/${file}.html"
MIMETYPE="text/html" #if not sure, use http://www.webmaster-toolkit.com/mime-types.shtml

if [ -f /home/koha/kohaclone/koha-tmpl/intranet-tmpl/notices/${file}.html ]
then
# DON'T CHANGE ANYTHING BELOW
TMP="/tmp/tmpfil_123"$RANDOM;
BOUNDARY=`date +%s|md5sum`
BOUNDARY=${BOUNDARY:0:32}
FILENAME=`basename $ATTACHMENT`

rm -rf $TMP;
cat $ATTACHMENT|uuencode --base64 $FILENAME>$TMP;
sed -i -e '1,1d' -e '$d' $TMP;#removes first & last lines from $TMP
DATA=`cat $TMP`

rm -rf $TMP;
fappend $TMP "From: $FREMAIL";
fappend $TMP "To: $TOEMAIL";
fappend $TMP "Reply-To: $FREMAIL";
fappend $TMP "Subject: $SUBJECT";
fappend $TMP "Content-Type: multipart/mixed; boundary=\""$BOUNDARY"\"";
fappend $TMP "";
fappend $TMP "This is a MIME formatted message.  If you see this text it means that your";
fappend $TMP "email software does not support MIME formatted messages.";
fappend $TMP "";
fappend $TMP "--$BOUNDARY";
fappend $TMP "Content-Type: text/plain; charset=ISO-8859-1; format=flowed";
fappend $TMP "Content-Transfer-Encoding: 7bit";
fappend $TMP "Content-Disposition: inline";
fappend $TMP "";
fappend $TMP "$MSGBODY";
fappend $TMP "";
fappend $TMP "";
fappend $TMP "--$BOUNDARY";
fappend $TMP "Content-Type: $MIMETYPE; name=\"$FILENAME\"";
fappend $TMP "Content-Transfer-Encoding: base64";
fappend $TMP "Content-Disposition: attachment; filename=\"$FILENAME\";";
fappend $TMP "";
fappend $TMP "$DATA";
fappend $TMP "";
fappend $TMP "";
fappend $TMP "--$BOUNDARY--";
fappend $TMP "";
fappend $TMP "";
#cat $TMP>out.txt
cat $TMP|/usr/lib/sendmail -t -v;
rm $TMP;
fi
