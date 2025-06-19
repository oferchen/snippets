#watch -n 2 'ip -s link | awk -v now=$(cut -d. -f1 /proc/uptime) '\''/^[0-9]+: /{gsub(":", "", $2); iface=$2} /RX:/{getline; rx=$1} /TX:/{getline; tx=$1; age=(rx==0&&tx==0)?"idle":"active"; printf("iface %s: RX=%s TX=%s – %s [%02d:%02d:%02d uptime]\n", iface, rx, tx, age, int(now/3600), int((now%3600)/60), now%60)}'\'
watch -n 2 '
ip -s link | awk -v now=$(cut -d. -f1 /proc/uptime) '\'' 
  /^[0-9]+: / {
    gsub(":", "", $2);
    iface = $2 
  } 
  /RX:/ {
    getline; rx = $1 
  } 
  /TX:/ {
    getline; tx = $1;
    age = (rx == 0 && tx == 0) ? "idle" : "active";
    printf("iface %-12s RX=%-10s TX=%-10s – %-6s [%02d:%02d:%02d uptime]\n", 
           iface, rx, tx, age, int(now/3600), int((now%3600)/60), now%60)
  }
'\'
