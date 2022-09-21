import vm/vm

import std/strutils

proc ctEncrypt(x: string): string {.compileTime.} = 
  let key = byte(x[0]) 

  result.add chr(key)

  for index in 1..x.high:
    let value = (byte(x[index])) xor key

    result.add chr(value) 

const
  password = ctEncrypt"3This_Is_the_Password"
  prompt = "Hello! Please enter your password: "

import std/strutils

proc runTimeEncrypt(machine: VirtualMachine, x: string): string =
  # r1 - char ptr
  # r2 - size of str 

  # instr with const - 9 bytes
  # instr with reg - 2 bytes
  # instr with none - 1 byte

  result = x.deepCopy

  const code = assemble"""
  pop r1
  pop r2

  pushr r1
  readb
  pop r3

  pushc 0x1
  pushr r1
  add
  pop r1

  pushc 0x1
  pushr r2
  sub
  pop r2

  Loop:
  pushr r3
  pushr r1
  readb
  xorb
  pushr r1
  writeb

  pushr r1
  pushc 0x1
  add
  pop r1

  pushc 0x1
  pushr r2
  sub
  pop r2

  pushc 0x0
  pushr r2
  jne Loop
  exit"""

  let strAddr = cast[Word](unsafeAddr(result[0]))

  machine.execute(code, [strAddr, Word(result.len)])

when isMainModule:
  let machine = VirtualMachine.new()

  echo prompt

  let input = strip stdin.readLine

  if machine.runTimeEncrypt(input) == password:
    echo "You solved this one!"
  else:
    echo "Try again!"


