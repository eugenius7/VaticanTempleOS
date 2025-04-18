asm {
// $LK,"::/Doc/MemOverview.DD"$

  USE32
  SYS_INIT_PAGE_TABLES::
//Check 1Gig page capability and set page size.
  MOV	EAX,0x80000001
  CPUID
  MOV	EAX,1<<21
//	BT	EDX,26
//	JNC	@@05
//	MOV	EAX,1<<30
           @@05:	MOV	U32 [MEM_PAGE_SIZE],EAX

//Set mapped space limit
           MOV	EAX,[MEM_PHYSICAL_SPACE]
           MOV	EDX,[MEM_PHYSICAL_SPACE+4]
           BT	U32 [MEM_PAGE_SIZE],30 //Round-up to 1Gig boundary?
           JNC	@@10
           ADD	EAX,0x3FFFFFFF
           ADC	EDX,0
           AND	EAX,~0x3FFFFFFF
         @@10:	INC	EDX	//Need 4Gig extra for uncached alias up at top of space.
           MOV	[MEM_MAPPED_SPACE],EAX
           MOV	[MEM_MAPPED_SPACE+4],EDX

//How many 2Meg pages?
           MOV	CL,21
           ADD	EAX,0x1FFFFF
           ADC	EDX,0
           SHRD	EAX,EDX
           SHR	EDX,CL
           MOV	[MEM_2MEG_NUM],EAX
           MOV	[MEM_2MEG_NUM+4],EDX

//How many 1Gig pages?
           MOV	CL,9
           ADD	EAX,0x1FF
           ADC	EDX,0
           SHRD	EAX,EDX
           SHR	EDX,CL
           MOV	[MEM_1GIG_NUM],EAX
           MOV	[MEM_1GIG_NUM+4],EDX

//How many 512Gig pages?
           MOV	CL,9
           ADD	EAX,0x1FF
           ADC	EDX,0
           SHRD	EAX,EDX
           SHR	EDX,CL
           MOV	[MEM_512GIG_NUM],EAX
           MOV	[MEM_512GIG_NUM+4],EDX

//Set $LK,"CSysFixedArea",A="MN:CSysFixedArea"$ to zero
           MOV	EDI,SYS_FIXED_AREA
           XOR	EAX,EAX
           MOV	ECX,sizeof(CSysFixedArea)/4
           REP_STOSD

           MOV	U32 [MEM_PML2],EDI
//Check for 1Gig page capability.
           BT	U32 [MEM_PAGE_SIZE],30
           JC	@@15
//Find PML2 Size
           MOV	EAX,U32 [MEM_2MEG_NUM]
           ADD	EAX,0x1FF
           AND	EAX,~0x1FF
           SHL	EAX,3
           ADD	EDI,EAX

//Find PML3 Size
         @@15:
           MOV	U32 [MEM_PML3],EDI
           MOV	EAX,U32 [MEM_1GIG_NUM]
           ADD	EAX,0x1FF
           AND	EAX,~0x1FF
           SHL	EAX,3
           ADD	EDI,EAX

//Find PML4 Size
           MOV	U32 [MEM_PML4],EDI
           MOV	EAX,U32 [MEM_512GIG_NUM]
           ADD	EAX,0x1FF
           AND	EAX,~0x1FF
           SHL	EAX,3
           ADD	EAX,EDI

           MOV	U32 [MEM_HEAP_BASE],EAX

//Set page tables to zero
           MOV	EDI,U32 [MEM_PML2]
           SUB	EAX,EDI
           MOV	ECX,EAX
           SHR	ECX,2
           XOR	EAX,EAX
           REP_STOSD

//Check for 1Gig page capability.
           BT	U32 [MEM_PAGE_SIZE],30
           JC	@@30

//PML2: Use 2Meg Pages
           MOV	EAX,0x87 //bit 7 is page size (2Meg)
           XOR	EDX,EDX
           MOV	EDI,[MEM_PML2]
           MOV	ECX,[MEM_2MEG_NUM]
         @@20:
           MOV	U32 [EDI],EAX
           ADD	EDI,4
           MOV	U32 [EDI],EDX
           ADD	EDI,4
           ADD	EAX,0x200000
           ADC	EDX,0
           LOOP	@@20
//PML3: Use 2Meg Pages
           MOV	EAX,[MEM_PML2]
           OR	EAX,7
           XOR	EDX,EDX
           MOV	EDI,[MEM_PML3]
           MOV	ECX,[MEM_1GIG_NUM]
         @@25:
           MOV	U32 [EDI],EAX
           ADD	EDI,4
           MOV	U32 [EDI],EDX
           ADD	EDI,4
           ADD	EAX,0x1000
           ADC	EDX,0
           LOOP	@@25
           JMP	@@40

//PML3: Use 1Gig Pages
         @@30:
           MOV	EAX,0x87 //bit 7 is page size (1Gig)
           XOR	EDX,EDX
           MOV	EDI,[MEM_PML3]
           MOV	ECX,[MEM_1GIG_NUM]
         @@35:
           MOV	U32 [EDI],EAX
           ADD	EDI,4
           MOV	U32 [EDI],EDX
           ADD	EDI,4
           ADD	EAX,0x40000000
           ADC	EDX,0
           LOOP	@@35

//PML4
         @@40:
           MOV	EAX,[MEM_PML3]
           OR	EAX,7
           XOR	EDX,EDX
           MOV	EDI,[MEM_PML4]
           MOV	ECX,[MEM_512GIG_NUM]
         @@45:
           MOV	U32 [EDI],EAX
           ADD	EDI,4
           MOV	U32 [EDI],EDX
           ADD	EDI,4
           ADD	EAX,0x1000
           ADC	EDX,0
           LOOP	@@45
           RET

           SYS_INIT_16MEG_SYS_CODE_BP::
// Init sys_code_bp to BIOS E801 lowest 16Meg val.
// $LK,"BlkPoolsInit",A="MN:BlkPoolsInit"$() adds the rest.
           MOV	U32 [SYS_CODE_BP],SYS_FIXED_AREA+CSysFixedArea.sys_code_bp
           MOV	U32 [SYS_CODE_BP+4],0

           MOV	U32 [SYS_DATA_BP],0
           MOV	U32 [SYS_DATA_BP+4],0

           XOR	EAX,EAX
           MOV	AX,U16 [MEM_E801] //1 Kb blks between 1M and 16M
           SHL	EAX,10
           ADD	EAX,0x100000
           MOV	EDI,U32 [MEM_HEAP_BASE]
           SUB	EAX,EDI

//EDI=BASE EAX=SIZE
           TEST	U8 [SYS_MEM_INIT_FLAG],1
           JZ	@@05
           PUSH	EAX
           PUSH	EDI
           MOV	ECX,EAX
           MOV	AL,U8 [SYS_MEM_INIT_VAL]
           REP_STOSB
           POP	EDI
           POP	EAX

         @@05:
           SHR	EAX,MEM_PAG_BITS
           MOV	ESI,SYS_FIXED_AREA+CSysFixedArea.sys_code_bp
           MOV	EBX,U32 CBlkPool.mem_free_lst[ESI]
           MOV	U32 CMemBlk.next[EDI],EBX
           MOV	U32 CMemBlk.next+4[EDI],0
           MOV	U32 CBlkPool.mem_free_lst[ESI],EDI
           MOV	U32 CBlkPool.mem_free_lst+4[ESI],0
           MOV	U32 CMemBlk.mb_signature[EDI],MBS_UNUSED_SIGNATURE_VAL
           MOV	U32 CMemBlk.pags[EDI],EAX
           SHL	EAX,MEM_PAG_BITS
           ADD	U32 CBlkPool.alloced_u8s[ESI],EAX

           BTS	U32 [SYS_RUN_LEVEL],RLf_16MEG_SYS_CODE_BP
           RET
}

I64 *MemPageTable(U8 *a)
{//Point to page table entry for addr.
  if (Bt(&mem_page_size,30))
    return *MEM_PML3(U64 *)+a>>30*8;
  else
    return *MEM_PML2(U64 *)+a>>21*8;
}
