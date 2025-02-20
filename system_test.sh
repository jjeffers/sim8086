URLS=(
  "https://raw.githubusercontent.com/cmuratori/computer_enhance/refs/heads/main/perfaware/part1/listing_0037_single_register_mov.asm"
  "https://raw.githubusercontent.com/cmuratori/computer_enhance/refs/heads/main/perfaware/part1/listing_0038_many_register_mov.asm"
)

rm test/* 2>/dev/null

for URL in "${URLS[@]}"; do
  echo "downloading ${URL}"
  curl --silent --create-dirs -O --output-dir test "$URL"
done

cd test

for ASM in *; do
  name="${ASM%.*}"
  echo "running nasm on ${ASM}"
  nasm -o "$name" "$ASM"
  echo "running sim8086 on ${name}"
  ../zig-out/bin/sim8086 "${name}" >"${name}.sim8086.disassembly"
  diff <(tail -n +17 ${ASM}) "${name}.sim8086.disassembly"

  error=$?
  if [ $error -eq 0 ]; then
    echo "SUCCESS"
  else
    >&2 echo "FAIL"
  fi
done
