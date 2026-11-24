#!/bin/bash
set -e

PROFILE="/root/funos"
WORK="/tmp/funos-work"
OUT="/src/out"
BIN="$PROFILE/airootfs/usr/local/bin"

echo ">>> 1. Создаю профиль из шаблона releng"
rm -rf "$PROFILE" "$WORK"
cp -r /usr/share/archiso/configs/releng "$PROFILE"
mkdir -p "$BIN" "$PROFILE/airootfs/root"

echo ">>> 2. Добавляю пакеты"
cat >> "$PROFILE/packages.x86_64" << 'EOF'

# --- FunOS ---
networkmanager
nano
vim
htop
git
python
curl
wget
fortune-mod
cowsay
figlet
sl
cmatrix
bsdgames
espeak-ng
neofetch
mesa
xorg-server
xorg-xinit
xfce4
xfce4-terminal
EOF

echo ">>> 3. Имя ISO и быстрое сжатие"
sed -i 's|^iso_name=.*|iso_name="funos"|' "$PROFILE/profiledef.sh"
sed -i 's|^iso_label=.*|iso_label="FUNOS_$(date +%Y%m)"|' "$PROFILE/profiledef.sh"
sed -i 's|^iso_publisher=.*|iso_publisher="FunOS Team"|' "$PROFILE/profiledef.sh"
sed -i 's|^iso_application=.*|iso_application="FunOS Live"|' "$PROFILE/profiledef.sh"
echo "airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3' '-b' '1M')" >> "$PROFILE/profiledef.sh"

echo ">>> 4. Автозапуск меню и файлы для XFCE"
cat > "$PROFILE/airootfs/root/.bash_profile" << 'EOF'
clear
figlet -f slant "FunOS" 2>/dev/null
fortune -s | cowsay -f tux 2>/dev/null
sleep 2
funos-menu
EOF

cat > "$PROFILE/airootfs/root/.xinitrc" << 'EOF'
exec startxfce4
EOF

echo ">>> 5. Пишу меню и игры"

cat > "$BIN/funos-menu" << 'EOF'
#!/bin/bash
pause() { read -rp "Нажмите Enter..." _; }
game() { if command -v "$1" >/dev/null 2>&1; then "$1"; else echo "Нет игры: $1"; sleep 1; fi; }

while true; do
  clear
  figlet -f small "FunOS"
  fortune -s | cowsay -f dragon 2>/dev/null
  echo
  echo "  1) Информация о системе"
  echo "  2) Змейка"
  echo "  3) Угадай число"
  echo "  4) Камень-ножницы-бумага"
  echo "  5) Тест реакции"
  echo "  6) Слоты"
  echo "  7) Тест скорости печати"
  echo "  8) Мемный генератор"
  echo "  9) Матрица (15 сек)"
  echo " 10) Паровозик"
  echo " 11) Говорящая система"
  echo " 12) Виселица (bsdgames)"
  echo " 13) Приключение (bsdgames)"
  echo " 14) Рабочий стол XFCE (startx)"
  echo "  0) Выход в консоль"
  echo
  read -rp "Выбор: " c
  case $c in
    1) neofetch; pause ;;
    2) snake ;;
    3) guess ;;
    4) rps ;;
    5) reaction ;;
    6) slots ;;
    7) typetest ;;
    8) meme ;;
    9) timeout 15 cmatrix -b ;;
    10) sl; pause ;;
    11) espeak-ng -v ru "Привет! Я FunOS. Добро пожаловать!" 2>/dev/null; pause ;;
    12) game hangman; pause ;;
    13) game adventure; pause ;;
    14) startx ;;
    0) break ;;
    *) echo "Нет такого пункта"; sleep 1 ;;
  esac
done
EOF

cat > "$BIN/snake" << 'EOF'
#!/bin/bash
W=30; H=12
x=15; y=6; dx=1; dy=0; score=0
fx=$((RANDOM % W)); fy=$((RANDOM % H))
body=("15,6")

cleanup() { stty sane; tput cnorm; clear; }
trap cleanup EXIT
stty -echo -icanon time 0 min 0
tput civis
clear

while true; do
  out=$'\033[H'
  out+="Счёт: $score   WASD - ход, q - выход\033[K\n"
  for ((r=0; r<H; r++)); do
    line="|"
    for ((c=0; c<W; c++)); do
      ch=" "
      if (( c == fx && r == fy )); then ch="*"; fi
      for b in "${body[@]}"; do [[ $b == "$c,$r" ]] && ch="o"; done
      line+="$ch"
    done
    out+="${line}|\033[K\n"
  done
  printf '%b' "$out"

  read -rsn1 -t 0.12 k
  case "$k" in
    w) (( dy != 1 ))  && { dx=0; dy=-1; } ;;
    s) (( dy != -1 )) && { dx=0; dy=1; } ;;
    a) (( dx != 1 ))  && { dx=-1; dy=0; } ;;
    d) (( dx != -1 )) && { dx=1; dy=0; } ;;
    q) break ;;
  esac

  x=$(( (x + dx + W) % W ))
  y=$(( (y + dy + H) % H ))

  for b in "${body[@]}"; do
    if [[ $b == "$x,$y" ]]; then
      clear; echo "Игра окончена! Счёт: $score"; sleep 2; exit 0
    fi
  done

  body=("$x,$y" "${body[@]}")
  if (( x == fx && y == fy )); then
    ((score++))
    fx=$((RANDOM % W)); fy=$((RANDOM % H))
  else
    unset "body[${#body[@]}-1]"
  fi
done
EOF

cat > "$BIN/guess" << 'EOF'
#!/bin/bash
n=$((RANDOM % 100 + 1)); tries=0
echo "Я загадал число от 1 до 100."
while true; do
  read -rp "Твой вариант: " g
  [[ $g =~ ^[0-9]+$ ]] || { echo "Введи число"; continue; }
  ((tries++))
  if   (( g < n )); then echo "Больше!"
  elif (( g > n )); then echo "Меньше!"
  else echo "Угадал за $tries попыток!"; break
  fi
done
read -rp "Enter..." _
EOF

cat > "$BIN/rps" << 'EOF'
#!/bin/bash
opts=(камень ножницы бумага)
read -rp "1 камень, 2 ножницы, 3 бумага: " p
case $p in 1) me=0;; 2) me=1;; 3) me=2;; *) echo "Ошибка"; exit;; esac
bot=$((RANDOM % 3))
echo "Ты: ${opts[$me]}   Я: ${opts[$bot]}"
if   (( me == bot )); then echo "Ничья"
elif (( (me + 1) % 3 == bot )); then echo "Ты выиграл!"
else echo "Я выиграл"
fi
read -rp "Enter..." _
EOF

cat > "$BIN/reaction" << 'EOF'
#!/bin/bash
clear
echo "Тест реакции. Когда экран станет ЗЕЛЁНЫМ, жми Enter как можно быстрее."
read -rp "Нажми Enter, чтобы начать..." _
sleep "$((RANDOM % 4 + 2)).$((RANDOM % 10))"
printf '\033[42m\033[30m   ЖМИ!   \033[0m\n'
start=$(date +%s%N)
read -r _
end=$(date +%s%N)
echo "Твоя реакция: $(( (end - start) / 1000000 )) мс"
read -rp "Enter..." _
EOF

cat > "$BIN/slots" << 'EOF'
#!/bin/bash
credits=100
s=(A B C 7 '*')
while true; do
  echo "Монет: $credits   (Enter - крутить, q - выход)"
  read -rp "> " k
  [[ $k == q ]] && break
  if (( credits < 10 )); then echo "Банкрот. Игра окончена."; break; fi
  credits=$((credits - 10))
  a=${s[RANDOM % 5]}; b=${s[RANDOM % 5]}; c=${s[RANDOM % 5]}
  echo "[ $a | $b | $c ]"
  if [[ $a == "$b" && $b == "$c" ]]; then
    echo "ДЖЕКПОТ! +100"; credits=$((credits + 100))
  elif [[ $a == "$b" || $b == "$c" || $a == "$c" ]]; then
    echo "Два одинаковых, +20"; credits=$((credits + 20))
  else
    echo "Не повезло"
  fi
  sleep 0.7
done
EOF

cat > "$BIN/typetest" << 'EOF'
#!/bin/bash
phrases=(
  "съешь ещё этих мягких французских булок"
  "linux это не ос, это образ жизни"
  "sudo make me a sandwich"
  "pacman -Syu и вперёд"
)
p=${phrases[RANDOM % ${#phrases[@]}]}
echo "Напиши фразу как можно быстрее:"
echo "$p"
start=$(date +%s)
read -rp "> " typed
end=$(date +%s)
secs=$(( end - start )); (( secs < 1 )) && secs=1
if [[ $typed == "$p" ]]; then
  echo "Без ошибок! Время: ${secs} с"
else
  echo "Есть опечатки. Время: ${secs} с"
fi
read -rp "Enter..." _
EOF

cat > "$BIN/meme" << 'EOF'
#!/bin/bash
a=("Я ничего не делал" "Это не баг, это фича" "Работает на моей машине" "Сейчас всё починю")
b=("а потом всё сломалось" "и меня уволили" "в продакшене" "за 5 минут до релиза")
echo "${a[RANDOM % ${#a[@]}]} ${b[RANDOM % ${#b[@]}]}" | cowsay -f stegosaurus 2>/dev/null
read -rp "Enter..." _
EOF

echo ">>> 6. Права в profiledef.sh (обязательно для archiso)"
grep -q '^file_permissions=(' "$PROFILE/profiledef.sh" \
  || { echo "Не нашёл file_permissions в profiledef.sh"; exit 1; }
PERM="$(mktemp)"
{
  for f in "$BIN"/*; do
    printf '  ["/usr/local/bin/%s"]="0:0:755"\n' "$(basename "$f")"
  done
  echo '  ["/root/.bash_profile"]="0:0:644"'
} > "$PERM"
sed -i "/^file_permissions=(/r $PERM" "$PROFILE/profiledef.sh"
rm -f "$PERM"

echo ">>> 7. Сборка ISO"
mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

echo ">>> ГОТОВО"
ls -lh "$OUT"/funos-*.iso
