import vm

import std/[macros, tables, strutils]

type
  Handler = proc(vm: VirtualMachine): bool

  ArgType* {.pure.} = enum 
    None
    Register
    Constant

  Registers* {.pure, size:1.} = enum
    R1
    R2
    R3
    R4

  OpCode* = object
    mnemonic*: string
    arg*: ArgType

    callback*: Handler

proc size*(o: OpCode): int = 
  result = sizeof(OpCodeId)

  case o.arg
  of ArgType.Register:
    result.inc sizeof(Registers)
  of ArgType.Constant:
    result.inc sizeof(Word)
  else: discard


var opcodes* {.compileTime.}: seq[OpCode]

proc parseArgument(vm: VirtualMachine, argType: ArgType): ptr Word =
  let nextByte = cast[uint](vm.ip) + 1

  case argType
  of ArgType.Register:
    let reg = cast[ptr Registers](nextByte)[]

    let regToPtr = {
      Registers.R1: unsafeAddr(vm.r1),
      Registers.R2: unsafeAddr(vm.r2),
      Registers.R3: unsafeAddr(vm.r3),
      Registers.R4: unsafeAddr(vm.r4), 
    }.toTable

    return regToPtr[reg]
  of ArgType.Constant:
    return cast[ptr Word](nextByte)
  of ArgType.None:
    return


macro register(mnemonic, arg, body: untyped) = 
  let 
    handlerIdent = newIdentNode($mnemonic & "Handler")
    argIdent = nnkDotExpr.newTree(
      newIdentNode("ArgType"), arg
    )
    mnemonicLit = newLit($mnemonic)

  let
    vmIdent = newIdentNode("vm")
    argumentIdent = newIdentNode("arg")

  let bodyStatements = newStmtList(body)

  result = quote do:
    proc `handlerIdent`(`vmIdent`: VirtualMachine): bool =
      let `argumentIdent` = vm.parseArgument(`argIdent`)
      result = false
      `bodyStatements`

    static:
      opcodes.add(OpCode(mnemonic: `mnemonicLit`, arg: `argIdent`, callback: `handlerIdent`))

converter ptrToNum*[T](x: ptr T): int = cast[int](x)
converter numToPtr*(x: int): ptr Word = cast[ptr Word](x)
converter numToOpCodePtr*(x: int): ptr OpCodeId = cast[ptr OpCodeId](x)

proc seek*(vm: VirtualMachine, displacement: int = 0): Word = 
  result = cast[type(vm.sp)](vm.sp + (displacement * sizeof(Word)))[]

proc pop*(vm: VirtualMachine): Word = 
  result = vm.sp[]
  vm.sp = vm.sp + sizeof(Word)

proc push*(vm: VirtualMachine, x: Word) = 
  vm.sp = vm.sp - sizeof(Word)
  vm.sp[] = x

## handlers start
register(exit, None):
  result = true

register(pushr, Register):
  vm.push arg[]

register(pushc, Constant):
  vm.push arg[]

register(pop, Register):
  arg[] = vm.pop

template cmpInstr(name, cond: untyped) = 
  register(name, Constant):
    let 
      first = vm.pop
      second = vm.pop
    
    if cond(first, second):
      vm.ip = cast[type(vm.ip)](cast[Word](vm.ip) + arg[])


template mathInstr(name, op: untyped) = 
  register(name, None):
    let 
      first = vm.pop
      second = vm.pop

    vm.push op(first, second)

mathInstr(add, `+`)
mathInstr(sub, `-`)
mathInstr(mul, `*`)
mathInstr(divu, `div`)
mathInstr(`and`, `and`)
mathInstr(`or`, `or`)
mathInstr(`xor`, `xor`)

register(xorb, None):
  let 
    first = vm.pop
    second = vm.pop

  vm.push byte(first xor second)


cmpInstr(je, `==`)
cmpInstr(jne, `!=`)
# cmpInstrBack(jnem, `!=`)  

cmpInstr(jb, `<`)  # jump bigger
cmpInstr(jl, `>`)  # jump lower

register(readb, None):
  let address = vm.pop
  vm.push cast[ptr byte](address)[]

register(readh, None):
  let address = vm.pop
  vm.push cast[ptr uint32](address)[]

register(readw, None):
  let address = vm.pop
  vm.push cast[ptr Word](address)[]


register(writeb, None):
  let address = vm.pop
  let value = vm.pop



  cast[ptr byte](address)[] = byte(value)

register(writeh, None):
  let address = vm.pop
  let value = vm.pop

  cast[ptr uint32](address)[] = uint32 value

register(writew, None):
  let address = vm.pop
  let value = vm.pop

  cast[ptr Word](address)[] = Word value

register(swap, None):
  let 
    f = vm.pop
    s = vm.pop

  vm.push s
  vm.push f

## handlers end

# exec related
const handlers* = block:
  var 
    result = initTable[OpCodeId, tuple[cb: Handler, size: int]](opcodes.len)
    counter: OpCodeId = 1

  for op in opcodes:
    var instrSize = op.size

    result[counter] = (cb: op.callback, size: instrSize)
    counter.inc

  result
