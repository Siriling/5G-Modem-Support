#!/bin/sh
# AI-based band selection
DATA_FILE="/var/log/band_data.log"
DEVICE="/dev/ttyUSB2"
BANDS="1,3,7,20,28,38,40,41,77,78,79"  # Common 4G/5G bands
collect_data() {
  for band in $(echo $BANDS | tr "," " "); do
    sh /usr/bin/band_lock.sh "$band"
    sleep 5
    signal=$(echo "AT+CSQ" | atinout - $DEVICE - | grep "+CSQ" | awk "{print \$2}" | cut -d"," -f1)
    [ -z "$signal" ] && signal=0
    echo "$(date),$band,$signal" >> $DATA_FILE
  done
}
select_best_band() {
  best_band=""
  best_signal=0
  while IFS="," read -r timestamp band signal; do
    [ "$signal" -gt "$best_signal" ] && { best_signal="$signal"; best_band="$band"; }
  done < $DATA_FILE
  echo "Best band: $best_band (Signal: $best_signal)"
  sh /usr/bin/band_lock.sh "$best_band"
}
if [ ! -f "$DATA_FILE" ]; then
  echo "Collecting initial band data..."
  collect_data
fi
select_best_band
