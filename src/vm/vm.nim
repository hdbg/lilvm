import std/[tables, strutils, endians, algorithm, sequtils]

type
  OpCodeId* = uint8
  Word* = uint64

const stackSize = (0x1000 + sizeof(Word)) and not(sizeof(Word))

type
  VirtualMachine* = ref object
    r1*, r2*, r3*, r4*: Word

    sp*: ptr Word
    ip*: ptr OpCodeId

    code*: seq[byte]
    stack: array[stackSize div sizeof(Word), Word]

import operations

proc reset*(vm: VirtualMachine) = 
  zeroMem(unsafeAddr vm.stack[0], sizeof(Word) * vm.stack.len)

  vm.r1 = 0
  vm.r2 = 0
  vm.r3 = 0
  vm.r4 = 0

  vm.sp = cast[ptr Word](unsafeAddr(vm.stack[vm.stack.high]))

proc new*(_: type VirtualMachine): VirtualMachine = 
  new result
  result.reset

proc step*(vm: VirtualMachine): bool = 
  let 
    nextHandlerId = cast[ptr OpCodeId](vm.ip)[]
    nextHandler = handlers[nextHandlerId]

  result = nextHandler.cb(vm)
  vm.ip = vm.ip + nextHandler.size

proc execute*(vm: VirtualMachine, code: seq[byte], initial: openarray[Word]) = 
  # vm.r1 = initial[0]
  # vm.r2 = initial[1]
  # vm.r3 = initial[2]
  # vm.r4 = initial[3]

  for d in initial.reversed:
    vm.push d

  vm.code = code
  vm.ip = unsafeAddr vm.code[0]
  

  while not vm.step(): discard

proc assemble*(code: string): seq[byte] {.compileTime.} = 
  var 
    lines = code.splitLines
    locations: Table[string, int]

  for l in lines.mitems:
    l = l.strip

    # comments support
    if l.startswith("#") or l.len == 0: continue

    # handle locations
    if l.endswith(":"):
      locations[l[0..<l.high]] = result.len + 1
      continue

    var 
      op: OpCode
      id: OpCodeId

    for o in opcodes:
      if l.startswith(o.mnemonic):
        op = o
        for (opid, handler) in handlers.pairs:
          if handler.cb == op.callback:
            id = opid
            break

    if op == type(op).default and id == type(id).default:
      echo l
      raise ValueError.newException("Op Code not found") 
    
    result.add OpCodeId(id)


    case op.arg
    of ArgType.Register: 
      let second = l.split(' ')[1]
      let byteToWrite: byte = case second.normalize
      of "r1": byte Registers.R1
      of "r2": byte Registers.R2
      of "r3": byte Registers.R3
      of "r4": byte Registers.R4
      else: raise ValueError.newException("invalid register type")

      result.add byteToWrite
    of ArgType.Constant: 
      let parsed = l.split(' ')[1]

      var toEncode: Word

      if locations.hasKey(parsed):
        toEncode = Word(locations[parsed] - result.len - op.size())
      else:
        toEncode = fromHex[Word](parsed)

      var mask: Word = 0xff

      for bits in 0..<sizeof(Word):
        let masked = toEncode and (mask shl (8 * bits)).Word
        result.add (masked shr (8 * bits).Word).byte



    of ArgType.None: discard