/*
- Mk more references to spec in comments

- ATAPI RW needs cleaning up / improving

- Rem Buffer alignment check and just do it on every call

- AHCIATAPISetMaxSpeed needs to be implemented

- TODO FIXME: Variable casting into AHCI memory-mapped areas caused strange crashes
	on a Ryzen with Gigabyte brand motherboard, all PCI devices AMD brand.
	Cmpiler casting internal functionality needs to be researched to fix those bugs.
	Example line that caused crashes with Page Faults and bad memory address on Ryzen:
		cmd_header = &port->cmd_lst_base(CPortCmdHeader *)[i];

*/

I64 AHCI_DEBUG = FALSE;
U0 AHCIDbgMode(Bool mode=ON)
{
  AHCI_DEBUG = mode;
}

U0 AHCIDbg(I64 port_num)
{
  CAHCIHba	*hba = blkdev.ahci_hba;
  CAHCIPort	*port = &hba->ports[port_num];
  "\n";
  CallerRep;
  "\nAHCI Port: %d"
  , port_num;
  "\nPort Interrupt Status: %b"
  , port->interrupt_status;
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_CPDS))
    "\n\tCold Port Detect Status";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_TFE))
    "\n\tTask File Error";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_HBFS))
    "\n\tHost Bus Fatal Error";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_HBDS))
    "\n\tHost Bus Data Error";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_IFS))
    "\n\tSATA Interface Fatal Error";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_INFS))
    "\n\tSATA Interface Non-Fatal Error";
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_OFS))
    "\n\tOverflow Status (HBA RX bytes > PRDT bytes)";
  "\nPort Command:          %b"
  , port->command;
  "\nPort Command Issue:    %b"
  , port->cmd_issue;
  "\nPort Task File Data:   %b"
  , port->task_file_data;
  if (PCIBt(&port->task_file_data, AHCI_PxTFDf_STS_ERR))
  {
    "\n\tTask File Data Error";
    "\n\tTask File Data Error Register: %b"
    , port->task_file_data.u8[1];
  }
  "\nPort Interrupt Enable: %b", port->interrupt_enable;
  "\nPort SATA Status:      %b"
  , port->sata_status;
  "\nPort SATA Ctrl:        %b"
  , port->sata_ctrl;
  "\nPort SATA Error:       %b"
  , port->sata_error;
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_I))
    "\n\tRecovered Data Integrity Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_M))
    "\n\tRecovered Communication Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_T))
    "\n\tTransient Data Integrity Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_C))
    "\n\tPersistent Communication Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_P))
    "\n\tSATA Protocol Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_ERR_E))
    "\n\tInternal Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_DIAG_I))
    "\n\tPHY Internal Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_DIAG_C))
    "\n\tLink Layer CRC Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_DIAG_H))
    "\n\tHandshake Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_DIAG_S))
    "\n\tLink Sequence Error";
  if (PCIBt(&port->sata_error, AHCI_PxSERR_DIAG_T))
    "\n\tTransport State Transition Error";
  "\nPort SATA Active:      %b"
  , port->sata_active;
  "\nPort SATA Notif:       %b"
  , port->sata_notif;
  "\n";
  "\nHBA Capabilities:      %b"
  , hba->caps;
  "\nHBA Interrupt Status:  %b"
  , hba->interrupt_status;
  if (hba->interrupt_status)
    "\n\t(Each set bit is a port with pending interrupt)";
  "\nHBA Ports Implemented: %b"
  , hba->ports_implemented;
  "\nHBA Version:           0x%0X"
  , hba->version;
  "\nHBA Ext Capabilities:  %b"
  , hba->caps_ext;
  if (PCIBt(&hba->caps_ext, AHCI_CAPSEXTf_BOH))
    "\n\tBIOS/OS Handoff supported.";
  if (PCIBt(&hba->caps_ext, AHCI_CAPSEXTf_NVMP))
    "\n\tNVMHCI Supported (Non-Volatile Memory Host Controller Interface)";
  "\nHBA BIOS/OS Handoff:   %b"
  , hba->bohc;
  if (PCIBt(&hba->bohc, AHCI_BOHCf_BOS))
    "\n\tBIOS owns AHCI Controller";
  if (PCIBt(&hba->bohc, AHCI_BOHCf_BB))
    "\n\tBIOS Busy";
  "\n";
}

I64 AHCILBA48CapacityGet(U16 *id_record)
{//Get capacity of drive, in LBA blocks.
//Capacity is stored in a U64, so we take the shortcut
//and access the U16-indexed ID record as U64 indexed. Zero-based value.
  return (id_record)(U64 *)[ATA_IDENT_LBA48_CAPACITY / 4] - 1;
}

I64 AHCIPortCmdSlotGet(I64 port_num)
{//Get next free command slot in port; if none, throw error.
  I64 i;
  CAHCIPort	*port	= &blkdev.ahci_hba->ports[port_num];
  U32 slots	= port->sata_active | port->cmd_issue;
  for (i = 0; i < blkdev.cmd_slot_cnt; i++)
  {
    if (!(slots & 1))
      return i;
    slots >>= 1;
  }
  AdamErr("AHCI: No empty command slots on port %d!\n", port_num);
  throw('AHCI');
}

I64 AHCIPortSignatureGet(I64 port_num)
{
  CAHCIPort *port;
  if (port_num < 0 || port_num > AHCI_MAX_PORTS)
    return NULL;
  port = &blkdev.ahci_hba->ports[port_num];
  return port->signature;
}

Bool AHCIPortIsIdle(I64 port_num)
{//Check if the command engine is running on port.
  return !(blkdev.ahci_hba->ports[port_num].command & (AHCI_PxCMDF_ST | AHCI_PxCMDF_CR |
              AHCI_PxCMDF_FR | AHCI_PxCMDF_FRE));
}

U0 AHCIPortCmdStop(I64 port_num)
{//Stop command engine on port.
  CAHCIPort *port = &blkdev.ahci_hba->ports[port_num];
  PCIBtr(&port->command, AHCI_PxCMDf_ST);
  PCIBtr(&port->command, AHCI_PxCMDf_FRE);
  while (PCIBt(&port->command, AHCI_PxCMDf_CR) || PCIBt(&port->command, AHCI_PxCMDf_FR));
}

U0 AHCIPortCmdStart(I64 port_num)
{//Start command engine on port.
  CAHCIPort *port = &blkdev.ahci_hba->ports[port_num];
  while (PCIBt(&port->command, AHCI_PxCMDf_CR));
  PCIBts(&port->command, AHCI_PxCMDf_FRE);
  PCIBts(&port->command, AHCI_PxCMDf_ST);
}

Bool AHCIPortWait(I64 port_num, F64 timeout, Bool throwing=TRUE)
{//Wait until DRQ & BSY are clear in port task file.
  CAHCIPort *port = &blkdev.ahci_hba->ports[port_num];
  U8 str[STR_LEN];
  do
  {
    if (!(port->task_file_data & (ATAS_DRQ | ATAS_BSY)))
      return TRUE;
    Yield; // don't hang OS
  }
  while (timeout > tS);
  if (throwing)
  {
    if (AHCI_DEBUG)
    {
      StrPrint(str, "Run AHCIDbg(%d);", port_num);
      Dbg(str);
    }
    AdamErr("AHCI: Port %d hung.\n", port_num);
    throw('AHCI');
  }
  return FALSE;
}

U0 AHCIPortReset(I64 port_num)
{//Software reset of port. Port command engine must be started after this.
//If port is not responsive we do a full reset.
  CAHCIPort *port = &blkdev.ahci_hba->ports[port_num];
  AHCIPortCmdStop(port_num);
  port->interrupt_status = port->interrupt_status; //Acknowledge all interrupt statuses.
  if (!AHCIPortWait(port_num, tS + 1))
  {
    //Perform 'more intrusive' HBA<->Port comm reset (sec. 10.4.2 of spec).
    port->sata_ctrl = AHCI_PxSCTLF_DET_INIT;
    Sleep(2); //Spec says 1 millisecond
    port->sata_ctrl = 0;
  }
  while (port->sata_status & 0xF != AHCI_PxSSTSF_DET_PRESENT);
  port->sata_error = ~0; //Write all 1s to sata error register.
}

CPortCmdHeader *AHCIPortActiveHeaderGet(I64 port_num, I64 cmd_slot)
{//Get current command slot header on port.
  CAHCIPort	*port = &blkdev.ahci_hba->ports[port_num];
  CPortCmdHeader	*cmd_header = port->cmd_lst_base;
  return cmd_header + cmd_slot; //Move up pointer to the slot we have in the command list.
}

U0 AHCIPortCmdWait(I64 port_num, I64 cmd_slot)
{//Wait on command completion after command issue, and double check any error.
  CAHCIPort *port = &blkdev.ahci_hba->ports[port_num];
  U8 str[STR_LEN];
  while (TRUE)
  {
    if (!PCIBt(&port->cmd_issue, cmd_slot)) //When command has been processed
      break;
    if (PCIBt(&port->interrupt_status, AHCI_PxIf_TFE)) //Task File Error ($LK,"ATAS_ERR",A="MN:ATAS_ERR"$)
    {
error:
      if (AHCI_DEBUG)
      {
        StrPrint(str, "Run AHCIDbg(%d);", port_num);
        Dbg(str);
      }
      AdamErr("AHCI: Port %d: Command failed!\n", port_num);
      throw('AHCI');
    }
    Yield; // don't hang OS
  }
  if (PCIBt(&port->interrupt_status, AHCI_PxIf_TFE)) //Second safety check
    goto error;
}

I64 AHCIAtapiCapacityGet(CBlkDev *bd)
{
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  U32	*buf;
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  buf = CAlloc(8, adam_task->code_heap);
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  //Set up single PRD
  cmd_table->prdt[0].data_base = buf;
  cmd_table->prdt[0].data_byte_cnt = DVD_BLK_SIZE - 1; //Zero-based value
  cmd_header->prdt_len = 1;
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  cmd_fis->lba1 = 8;
  cmd_table->acmd[0]	= ATAPI_READ_CAPACITY >> 8;
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return 0;
  }
  return EndianU32(buf[0]);
}

Bool AHCIAtapiSync(CBlkDev *bd)
{// Sync drive read write buffers.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  cmd_table->acmd[0]	= ATAPI_SYNC_CACHE >> 8;
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
  return TRUE;
}

Bool AHCIAtapiClose(CBlkDev *bd, I64 close_field=0x200, I64 track=0)
{// Close track/session on a disc.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  CAtapiCloseCmd close_cmd;
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  MemSet(&close_cmd, 0, sizeof(CAtapiCloseCmd));
  close_cmd.command	= ATAPI_CLOSE_TRACK_SESSION >> 8;
  close_cmd.code	= close_field.u8[1];
  close_cmd.track_num	= EndianU16(track);
  MemCpy(&cmd_table->acmd, &close_cmd, sizeof(CAtapiCloseCmd));
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
  return TRUE;
}

Bool AHCIAtapiBlank(CBlkDev *bd, Bool minimal=TRUE)
{// Blank a disc. If minimal set FALSE, entire disc is blanked.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  cmd_table->acmd[0]	= ATAPI_BLANK >> 8;
  cmd_table->acmd[1]	= minimal;
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
  return TRUE;
}

Bool AHCIAtapiModeWriteSelect(CBlkDev *bd)
{// Set ATAPI drive write configuration.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  CAtapiModeWriteList	*mode_lst;
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  mode_lst = CAlloc(sizeof(CAtapiModeWriteList), adam_task->code_heap);
  mode_lst->page.code	= 0x05;	// Write Parameters mode page code
  mode_lst->page.length	= 0x32;	// 0x32 indicates no support for Vendor Specific field.
  mode_lst->page.type	= 0x00;	// Packet/Incremental mode
  mode_lst->page.mode	= 4 | 1 << 5;	// Set CD Track Mode, set Fixed Packet Size bit
  mode_lst->page.block_type	= 8;	// Mode 1: 2048-size blocks of data
  mode_lst->page.packet_size	= EndianU32(
          16); // Number of User Data Blocks per Fixed Packet. DVD media default: 16.
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  cmd_table->prdt[0].data_base	= mode_lst;
  cmd_table->prdt[0].data_byte_cnt	= sizeof(CAtapiModeWriteList) -
      1; // zero based, size of mode write list
  cmd_header->prdt_len = 1;
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  cmd_fis->feature_low= 0x01; // Core Feature, 'mandatory'
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  cmd_table->acmd[0]	= ATAPI_MODE_SELECT >> 8;
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
  return TRUE;
}

Bool AHCIAtapiStartStop(CBlkDev *bd, Bool start)
{
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  cmd_fis	= cmd_table->cmd_fis;
  cmd_fis->type	= FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  cmd_fis->command	= ATA_PACKET;
  cmd_table->acmd[0]	= ATAPI_START_STOP_UNIT >> 8;
  cmd_table->acmd[4]	= start;
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  try
    AHCIPortCmdWait(bd->port_num, cmd_slot);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
  return TRUE;
}

Bool DiscEject(U8 drv_let)
{// returns whether disc tray was successfully ejected.
  try
    return AHCIAtapiStartStop(Let2BlkDev(drv_let), 2);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
}

Bool DiscLoad(U8 drv_let)
{// returns whether disc tray was successfully closed & disc loaded.
  try
    return AHCIAtapiStartStop(Let2BlkDev(drv_let), 3);
  catch
  {
    Fs->catch_except = TRUE;
    return FALSE;
  }
}

U0 AHCIPortIdentify(CBlkDev *bd, Bool verbose=FALSE)
{//Perform ATA_IDENTIFY command on ATA/ATAPI drive and store capacity and id record.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port	= bd->ahci_port;
  I64 cmd_slot	= AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header	= AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  U16	*dev_id_record;
  port->interrupt_status = port->interrupt_status; //TODO: Why?
  //Using the code heap for this alloc to stay under 32-bit address space.
  dev_id_record = CAlloc(512, adam_task->code_heap);
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  //Set up single PRD
  cmd_table->prdt[0].data_base = dev_id_record;
  cmd_table->prdt[0].data_base_upper = 0;
  cmd_table->prdt[0].data_byte_cnt = 512 - 1; //Zero-based value
  cmd_header->prdt_len =
      1; //1 PRD, as described above, which contains the address to put the ID record.
  //Setup command FIS
  cmd_fis = cmd_table->cmd_fis;
  cmd_fis->type = FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS.
  if (port->signature == AHCI_PxSIG_ATAPI)
    cmd_fis->command = ATA_IDENTIFY_PACKET;
  else
    cmd_fis->command = ATA_IDENTIFY;
  cmd_fis->device = 0; //No bits need to be set in the device register.
  //Wait on previous command to complete.
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot); //Issue the command.
  AHCIPortCmdWait(bd->port_num, cmd_slot);
  Free(bd->dev_id_record);
  bd->dev_id_record = dev_id_record;
  if (port->signature == AHCI_PxSIG_ATA)
  {
    bd->max_blk = AHCILBA48CapacityGet(dev_id_record);
    if (verbose) "(Max Block: %d, Dsk Size: %d MiB)\n", bd->max_blk,
      bd->max_blk * BLK_SIZE / 1024 / 1024;
  }
  else
  {
    bd->max_blk = AHCIAtapiCapacityGet(bd);
    if (verbose) "(Max Block: %d, Dsk Size: %d MiB)\n", bd->max_blk,
      bd->max_blk * DVD_BLK_SIZE / 1024 / 1024;
  }
}

U8 *AHCIBufferAlign(CBlkDev *bd, U8 *user_buf, I64 buf_size, Bool write)
{//Make sure buffer is accessible by HBA controller.
//Controller requires a U16 aligned buffer and in 32-bit address space
//We are not using 64-bit capabilities.
//MAlloc provides U64-aligned addresses, and can allocate in the code heap ( <4GB ).
//In the case of an inadequate buffer address being passed in,
//we will use a MAlloced internal buffer.
  if (user_buf + buf_size > U32_MAX || user_buf & 1)
  {
    //if the buffer is not within 32-bit address space or not U16-aligned
//	"Aligning buffer under 32-bit range\n";
    Free(bd->prd_buf);
    bd->prd_buf = MAlloc(buf_size, adam_task->code_heap);
    PCIBts(&bd->flags, BDf_INTERNAL_BUF);
    if (write)
      MemCpy(bd->prd_buf, user_buf, buf_size);
    return bd->prd_buf;
  }
  PCIBtr(&bd->flags, BDF_INTERNAL_BUF);
  return user_buf;
}

I64 AHCIAtaBlksRW(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt, Bool write)
{//Read/Write ATA disk blocks. Returns number of bytes transferred between adam and disk.
//Don't use this, use the AHCIAtaBlksRead and AHCIAtaBlksWrite functions.
  CPortCmdTable *cmd_table;
  CFisH2D *cmd_fis;
  CAHCIPort *port = bd->ahci_port;
  I64 i, buf_size, buf_size_tmp, byte_cnt, prdt_len,
      cmd_slot = AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader *cmd_header = AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  U8 *internal_buf_tmp, *internal_buf;
  Bool	unlock;
  if (port->signature != AHCI_PxSIG_ATA)
  {
    AdamErr("AHCI: Drive is not an ATA drive!\n");
    throw('AHCI');
  }
  if (cnt < 1) return 0;
  if (cnt > AHCI_PRDT_MAX_BLOCKS)
  {
    AdamErr("AHCI: Block cnt %d max allowed in one command (%d)",
      cnt, AHCI_PRDT_MAX_BLOCKS);
    throw('AHCI');
  }
  unlock = BlkDevLock(bd);
  //Determine buffer size and PRDT length.
  buf_size = buf_size_tmp = cnt * BLK_SIZE;
  prdt_len = (buf_size - 1) / AHCI_PRD_MAX_BYTES + 1;
  cmd_header->prdt_len = prdt_len; //Set PRD table length in cmd header.
  //Set 'write' bit depending on 'write' argument.
  BEqu(&cmd_header->desc, AHCI_CH_DESCf_W, write);
  internal_buf = internal_buf_tmp = AHCIBufferAlign(bd, buf, buf_size, write);
  if (!internal_buf) throw('AHCI'); //Will probably never happen.
  //Obtain command table and zero it. This contains the command FIS and the PRDT.
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  //Create 'prdt_len' amount of PRD entries in the command table
  for (i = 0; i < prdt_len; i++)
  {
    //Use max PRD size until the remaining buffer is smaller than max size.
    if (buf_size_tmp > AHCI_PRD_MAX_BYTES)
      byte_cnt = AHCI_PRD_MAX_BYTES;
    else
      byte_cnt = buf_size_tmp;
    cmd_table->prdt[i].data_base = internal_buf_tmp;
    cmd_table->prdt[i].data_byte_cnt = byte_cnt - 1; //Zero-based value
    buf_size_tmp -= byte_cnt;
    internal_buf_tmp += byte_cnt;
  }
  //Setup the command FIS.
  cmd_fis = cmd_table->cmd_fis;
  cmd_fis->type = FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS
  if (write) //Assumed support for LBA48.
    cmd_fis->command = ATA_WRITE_DMA_EXT;
  else
    cmd_fis->command = ATA_READ_DMA_EXT;
  //Fill in the rest of the command FIS.
  cmd_fis->lba0	= blk.u8[0];
  cmd_fis->lba1	= blk.u8[1];
  cmd_fis->lba2	= blk.u8[2];
  cmd_fis->device	= 1 << 6; //Required as per ATA8-ACS section 7.25.3
  cmd_fis->lba3	= blk.u8[3];
  cmd_fis->lba4	= blk.u8[4];
  cmd_fis->lba5	= blk.u8[5];
  cmd_fis->cnt	= cnt;
  //Wait on previous command to complete.
  AHCIPortWait(bd->port_num, tS + 2);
  //Issue the command.
  PCIBts(&port->cmd_issue, cmd_slot);
  //Wait on command to finish.
  AHCIPortCmdWait(bd->port_num, cmd_slot);
  if (!write) //If internal_buf was created it back to argument buf.
    if (bd->flags & BDF_INTERNAL_BUF)
    {
//	"Writing back internal buffer\n";
      MemCpy(buf, internal_buf, buf_size);
    }
  if (unlock)
    BlkDevUnlock(bd);
  return cmd_header->prd_byte_cnt;
}

I64 AHCIAtaBlksRead(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt)
{//Read 'cnt' blocks from block 'blk' in AHCI disk dev and bytes transferred cnt.
  I64 byte_cnt = 0;
  if (!cnt)
    return 0;
  if (cnt <= AHCI_PRDT_MAX_BLOCKS)
  {
    return AHCIAtaBlksRW(bd, buf, blk, cnt, FALSE);
  }
  else
  {
    while (cnt > AHCI_PRDT_MAX_BLOCKS)
    {
      byte_cnt += AHCIAtaBlksRW(bd, buf, blk, AHCI_PRDT_MAX_BLOCKS, FALSE);
      cnt -= AHCI_PRDT_MAX_BLOCKS;
      blk += AHCI_PRDT_MAX_BLOCKS;
      buf += AHCI_PRDT_MAX_BLOCKS * BLK_SIZE;
    }
    byte_cnt += AHCIAtaBlksRW(bd, buf, blk, cnt, FALSE);
  }
  blkdev.read_cnt += (cnt * bd->blk_size) >> BLK_SIZE_BITS;
  return byte_cnt;
}

I64 AHCIAtaBlksWrite(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt)
{//Write 'cnt' blocks from block 'blk' in AHCI disk dev and return bytes transferred cnt.
  I64 byte_cnt = 0;
  if (!cnt)
    return 0;
  if (cnt <= AHCI_PRDT_MAX_BLOCKS)
  {
    return AHCIAtaBlksRW(bd, buf, blk, cnt, TRUE);
  }
  else
  {
    while (cnt > AHCI_PRDT_MAX_BLOCKS)
    {
      byte_cnt += AHCIAtaBlksRW(bd, buf, blk, AHCI_PRDT_MAX_BLOCKS, TRUE);
      cnt -= AHCI_PRDT_MAX_BLOCKS;
      blk += AHCI_PRDT_MAX_BLOCKS;
      buf += AHCI_PRDT_MAX_BLOCKS * BLK_SIZE;
    }
    byte_cnt += AHCIAtaBlksRW(bd, buf, blk, cnt, TRUE);
  }
  return byte_cnt;
}

I64 AHCIAtapiBlksRead(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt, Bool lock=TRUE)
{//Read 'cnt' blocks from block 'blk' in AHCI ATAPI dev and returns bytes transferred cnt.
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port = bd->ahci_port;
  I64 i, byte_cnt, buf_size, buf_size_tmp, prdt_len,
             cmd_slot = AHCIPortCmdSlotGet(bd->port_num);
  CPortCmdHeader	*cmd_header = AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  U8	*internal_buf, *internal_buf_tmp;
  CAtapiReadCmd read_cmd;
  Bool unlock;
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  if (cnt < 1)
    return 0;
  if (lock)
    unlock = BlkDevLock(bd);
  buf_size = buf_size_tmp = cnt * DVD_BLK_SIZE;
  prdt_len = (buf_size - 1) / AHCI_PRD_MAX_BYTES + 1;
  cmd_header->prdt_len = prdt_len;
  internal_buf = internal_buf_tmp = AHCIBufferAlign(bd, buf, buf_size, FALSE);
  if (!internal_buf) throw('AHCI');
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A); //Set ATAPI flag in command header
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  for (i = 0; i < prdt_len; i++)
  {
    if (buf_size_tmp > AHCI_PRD_MAX_BYTES) //$BK,1$SHOULD PROBABLY BE ATAPI MAX BYTES$BK,0$
      byte_cnt = AHCI_PRD_MAX_BYTES;
    else
      byte_cnt = buf_size_tmp;
    cmd_table->prdt[i].data_base = internal_buf_tmp;
    cmd_table->prdt[i].data_byte_cnt = byte_cnt - 1; //Zero-based value
    buf_size_tmp -= byte_cnt;
    internal_buf_tmp += byte_cnt;
  }
  cmd_fis = cmd_table->cmd_fis;
  MemSet(cmd_fis, 0, sizeof(CFisH2D));
  cmd_fis->type = FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS
  cmd_fis->feature_low = 1; //Necessary?
  cmd_fis->command = ATA_PACKET;
  MemSet(&read_cmd, 0, sizeof(CAtapiReadCmd));
  read_cmd.command = ATAPI_READ >> 8; //$BK,1$FIX$BK,0$
  read_cmd.lba = EndianU32(blk);
  read_cmd.cnt = EndianU32(cnt);
  MemCpy(&cmd_table->acmd, &read_cmd, 16);
  cmd_fis->cnt = cnt; //Necessary?
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot);
  AHCIPortCmdWait(bd->port_num, cmd_slot);
  if (bd->flags & BDF_INTERNAL_BUF)
  {
//	"Writing back internal buffer\n";
    MemCpy(buf, internal_buf, buf_size);
  }
  if (lock && unlock)
    BlkDevUnlock(bd);
  return cmd_header->prd_byte_cnt;
}

I64 AHCIAtapiBlksWrite(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt, Bool lock=TRUE)
{// Write blocks to a disc. (AHCIAtapiModeWriteSet must be called first.)
  CPortCmdTable	*cmd_table;
  CFisH2D	*cmd_fis;
  CAHCIPort	*port = bd->ahci_port;
  I64 i, byte_cnt, buf_size, buf_size_tmp, prdt_len, cmd_slot;
  CPortCmdHeader	*cmd_header;
  U8	*internal_buf, *internal_buf_tmp;
  CAtapiWriteCmd write_cmd;
  Bool unlock;
  if (port->signature != AHCI_PxSIG_ATAPI)
  {
    AdamErr("AHCI: Drive is not an ATAPI drive!\n");
    throw('AHCI');
  }
  if (cnt < 1)
    return 0;
  if (lock)
    unlock = BlkDevLock(bd);
  cmd_slot = AHCIPortCmdSlotGet(bd->port_num);
  cmd_header = AHCIPortActiveHeaderGet(bd->port_num, cmd_slot);
  buf_size = buf_size_tmp = cnt * DVD_BLK_SIZE;
  prdt_len = (buf_size - 1) / AHCI_PRD_MAX_BYTES + 1;
  cmd_header->prdt_len = prdt_len;
  internal_buf = internal_buf_tmp = AHCIBufferAlign(bd, buf, buf_size, TRUE);
  if (!internal_buf) throw('AHCI');
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_A); //Set ATAPI flag in command header
  PCIBts(&cmd_header->desc, AHCI_CH_DESCf_W); //Set WRITE flag in command header
  cmd_table = cmd_header->cmd_table_base;
  MemSet(cmd_table, 0, sizeof(CPortCmdTable));
  for (i = 0; i < prdt_len; i++)
  {
    if (buf_size_tmp > AHCI_PRD_MAX_BYTES)
      byte_cnt = AHCI_PRD_MAX_BYTES;
    else
      byte_cnt = buf_size_tmp;
    cmd_table->prdt[i].data_base = internal_buf_tmp;
    cmd_table->prdt[i].data_byte_cnt = byte_cnt - 1; //Zero-based value
    buf_size_tmp -= byte_cnt;
    internal_buf_tmp += byte_cnt;
  }
  cmd_fis = cmd_table->cmd_fis;
  MemSet(cmd_fis, 0, sizeof(CFisH2D));
  cmd_fis->type = FISt_H2D;
  PCIBts(&cmd_fis->desc, AHCI_CF_DESCf_C); //Set Command bit in H2D FIS
  cmd_fis->command = ATA_PACKET;
  if (cnt > U16_MAX) throw('AHCI');
  MemSet(&write_cmd, 0, sizeof(CAtapiWriteCmd));
  write_cmd.command = ATAPI_WRITE >> 8;
  write_cmd.lba = EndianU32(blk);
  write_cmd.cnt = EndianU16(cnt);
  MemCpy(&cmd_table->acmd, &write_cmd, sizeof(CAtapiWriteCmd));
  AHCIPortWait(bd->port_num, tS + 2);
  PCIBts(&port->cmd_issue, cmd_slot);
  AHCIPortCmdWait(bd->port_num, cmd_slot);
  if (bd->flags & BDF_INTERNAL_BUF)
  {
//	"Writing back internal buffer\n";
    MemCpy(buf, internal_buf, buf_size);
  }
  if (lock && unlock)
    BlkDevUnlock(bd);
  return cmd_header->prd_byte_cnt;
}

U0 AHCIPortInit(CBlkDev *bd, CAHCIPort *port, I64 port_num)
{//Initialize base addresses for command list and FIS receive area and start execution.
  CPortCmdHeader	*cmd_header,
                  *cmd_header_base;
  I64 i;
  if (!(port->signature == AHCI_PxSIG_ATAPI || port->signature == AHCI_PxSIG_ATA))
    Dbg("AHCI Port/BlkDev error: Invalid Port Signature");
  if (Let2BlkDevType(bd->first_drv_let) == BDT_AHCI_SATA
      && port->signature == AHCI_PxSIG_ATAPI)
    Dbg("AHCI Port/BlkDev type mismatch: BlkDev ATA, Port ATAPI");
  if (Let2BlkDevType(bd->first_drv_let) == BDT_AHCI_SATAPI
      && port->signature == AHCI_PxSIG_ATA)
    Dbg("AHCI Port/BlkDev type mismatch: BlkDev ATAPI, Port ATA");
  bd->ahci_port = port;
  bd->port_num = port_num;
  AHCIPortReset(port_num);
  AHCIPortCmdStart(port_num);
  // Spin up, power on device.
  // If the capability isn't suppport the bits will be read-only.
  port->command |= AHCI_PxCMDF_POD | AHCI_PxCMDF_SUD;
  Sleep(100); //Why?
  AHCIPortCmdStop(port_num);
  //'1K-byte' align as per SATA spec.
  port->cmd_lst_base = CAllocAligned(sizeof(CPortCmdHeader) * blkdev.cmd_slot_cnt, 1024,
          adam_task->code_heap);
  port->cmd_lst_base_upper = 0;
  //Alloc where received FISes will be copied to. '256-byte' align as per spec.
  port->fis_base = CAllocAligned(sizeof(CFisReceived), 256, adam_task->code_heap);
  port->fis_base_upper = 0;
  cmd_header_base = port->cmd_lst_base;
  for (i = 0; i < blkdev.cmd_slot_cnt; i++)
  {
    cmd_header = &cmd_header_base[i];
    //Write Command FIS Length (CFL, a fixed size) in bits 4:0 of the desc.
    cmd_header->desc = sizeof(CFisH2D) / sizeof(U32);
    //'128-byte' align as per SATA spec, minus 1 since length is 1-based.
    cmd_header->cmd_table_base = CAllocAligned(sizeof(CPortCmdTable) +
            sizeof(CPrdtEntry) * (AHCI_PRDT_MAX_LEN - 1), 128, adam_task->code_heap);
    cmd_header->cmd_table_base_upper = 0;
  }
  AHCIPortCmdStart(port_num);
  AHCIPortIdentify(bd);
}

Bool AHCIAtaInit(CBlkDev *bd)
{
  Bool	unlock, okay = FALSE;
  CPortCmdHeader *cmd_header, *cmd_header_base;
  I64	i;
  if (!bd->ahci_port)
    return FALSE;
  unlock = BlkDevLock(bd);
  // if we re-init a port, keep memory from leaking.
  if (bd->ahci_port->cmd_lst_base)
  {
    for (i = 0; i < blkdev.cmd_slot_cnt; i++)
    {
      cmd_header_base = bd->ahci_port->cmd_lst_base;
      cmd_header = &cmd_header_base[i];
      Free(cmd_header->cmd_table_base);
    }
    Free(bd->ahci_port->cmd_lst_base);
    Free(bd->ahci_port->fis_base);
  }
  // try to init the port, catch if fails.
  try
  {
    AHCIPortInit(bd, bd->ahci_port, bd->port_num);
    if (bd->type == BDT_AHCI_SATAPI)
      okay = AHCIAtapiStartStop(bd, TRUE);
    else
      okay = TRUE;
  }
  catch
  {
    Fs->catch_except = TRUE;
    okay = FALSE;
    ST_WARN_ST "AHCIAtaInit";
  }
  if (unlock)
    BlkDevUnlock(bd);
  return okay;
}

U0 AHCIHbaReset()
{
  PCIBts(&blkdev.ahci_hba->ghc, AHCI_GHCf_HBA_RESET);
  while (PCIBt(&blkdev.ahci_hba->ghc, AHCI_GHCf_HBA_RESET));
  PCIBts(&blkdev.ahci_hba->ghc, AHCI_GHCf_AHCI_ENABLE);
}


Bool AHCIInit(I64 addr=NULL)
{
  CAHCIHba *hba = NULL;
  CAHCIPort *port;
  I64 i, bdf, timeout;
  "______________________\n\n";
  if (blkdev.ahci_hba)
    return FALSE;
  if (!addr)
  {
    bdf = PCIClassFind(PCIC_STORAGE << 16 | PCISC_AHCI << 8 + 1,
            0); //0x010601, last byte prog_if, AHCI version 1.0
    if (bdf == -1)
    {
      "AHCI: No AHCI controller found on PCI bus!\n";
    }
    else
    {
      "AHCI: PCI controller found\n";
      hba = PCIReadU32(bdf.u8[2], bdf.u8[1], bdf.u8[0],
              PCIR_BASE5) & ~0x1F; //Last 4 bits not part of address.
    }
    // Skip for now to prevent delay
    /*
    if (hba == NULL)
    {
      bdf = GetPcieDevBar(PCIC_STORAGE, PCISC_AHCI, 5);
      if (bdf == -1)
      {
        //TODO
        "AHCI: No AHCI controller found on PCIe bus! (support is limited)\n";
      }
      else
      {
        "AHCI: PCIE controller found\n";
        hba = bdf;
      }
    }
    */
    if (hba == NULL)
      return FALSE;
  }
  else
  {
    "AHCI: No AHCI controller found.\n";
    return FALSE;
  }
  "AHCI: Controller found\n";
  hba = PCIReadU32(bdf.u8[2], bdf.u8[1], bdf.u8[0],
          PCIR_BASE5) & ~0x1F; //Last 4 bits not part of address.
  *MemPageTable(hba)=*MemPageTable(hba)&~0x18 |0x11;
  *MemPageTable(hba+mem_page_size)=*MemPageTable(hba+mem_page_size)&~0x18 |0x11;
  InvlPg(hba);
  InvlPg(hba+mem_page_size);
  blkdev.ahci_hba = hba;
  PCIBts(&blkdev.ahci_hba->ghc, AHCI_GHCf_AHCI_ENABLE);
  //"AHCI: GHC.AE set\n";
  //Transferring ownership from BIOS if supported.
  if (PCIBt(&hba->caps_ext, AHCI_CAPSEXTf_BOH))
  {
    PCIBts(&hba->bohc, AHCI_BOHCf_OOS);
    PortNop;
    //"AHCI: Transferring ownership from BIOS\n";
    timeout=10;
    while (PCIBt(&hba->bohc, AHCI_BOHCf_BOS)&&timeout)
    {
      Sleep(5);
      timeout--;
      if (!Bt(&hba->bohc, AHCI_BOHCf_BOS))
        break;
      else if (timeout==1)
        Bts(&hba->bohc, AHCI_BOHCf_OOS);
    }
    Sleep(25);
    if (PCIBt(&hba->bohc,
            AHCI_BOHCf_BB)) //if Bios Busy is still set after 25 mS, wait 2 seconds.
      Sleep(2000);
  }
  blkdev.cmd_slot_cnt = (hba->caps & 0x1F00) >> 8;
  //"AHCI: Command slot cnt: %d\n", blkdev.cmd_slot_cnt;
  for (i = 0; i < AHCI_MAX_PORTS; i++)
  {
    if (PCIBt(&hba->ports_implemented, i))
    {
      //$BK,1$Mk ports idle?$BK,0$
      port = &hba->ports[i];
      if (port->signature == AHCI_PxSIG_ATA || port->signature == AHCI_PxSIG_ATAPI)
      {
        "AHCI: Port %2d signature 0x%08X "
        , i, port->signature;
        if (port->signature == AHCI_PxSIG_ATAPI)
        {
          PCIBts(&port->command, AHCI_PxCMDf_ATAPI);
          "ATAPI drive\n";
        }
        else if (port->signature == AHCI_PxSIG_ATA)
          "ATA drive\n";
        if (!AHCIPortIsIdle(i))
        {
          "AHCI: Port %2d not idle, stopping port\n", i;
          AHCIPortCmdStop(i);
        }
      }
    }
  }
  "______________________\n\n";
  return TRUE;
}

Bool AHCIBootDVDProbeAll(CBlkDev *bd)
{
  I64 i;
  CAHCIPort	*port;
  U8	*buf = CAlloc(DVD_BLK_SIZE);
  CKernel	*kernel;
  "______________________\n";
  for (i = 0; i < AHCI_MAX_PORTS; i++)
  {
    if (PCIBt(&blkdev.ahci_hba->ports_implemented, i))
    {
      port = &blkdev.ahci_hba->ports[i];
      "AHCI: BootDVDProbeAll: Saw port at %2d with signature 0x%0X\n"
      , i, port->signature;
      if (port->signature == AHCI_PxSIG_ATAPI)
      {
        "AHCI: Probing ATAPI drive at port %d\n", i;
        try
        {
          AHCIPortInit(bd, port, i);
          AHCIAtapiBlksRead(bd, buf, sys_boot_blk, 1, FALSE);
          kernel = buf + sys_boot_src.u16[1] << BLK_SIZE_BITS;
          if (kernel->compile_time == sys_compile_time)
          {
            "AHCI: Found sys_compile_time at BLK %d on Port %d\n", sys_boot_blk, i;
            "______________________\n";
            return TRUE;
          }
          else
            "AHCI: Did not find matching sys_compile_time at BLK %d on Port %d\n",
            sys_boot_blk, i;
        }
        catch
        {
          Fs->catch_except = TRUE;
          "AHCI: Error at Port %d\n"
          , i;
        }
      }
    }
  }
  Panic("Could not find ATAPI boot drive");
  return FALSE;
}

Bool AHCIAtapiRBlks(CDrv *drive, U8 *buf, I64 blk, I64 cnt)
{
  CBlkDev	*bd	= drive->bd;
  I64 spc	= bd->blk_size >> BLK_SIZE_BITS, n, blk2,
           l2	= bd->max_reads << 1 + spc << 1;
  U8	*dvd_buf;//	= MAlloc(l2 << BLK_SIZE_BITS);
  if (bd->type == BDT_AHCI_SATAPI)
  {
    dvd_buf	= MAlloc(l2 << BLK_SIZE_BITS);
    if (blk <= bd->max_reads)
      blk2 = 0;
    else
      blk2 = FloorU64(blk - bd->max_reads, spc);
    if (blk2 + l2 > drive->size + drive->drv_offset)
      l2 = drive->size + drive->drv_offset - blk2;
    n = (l2 + spc - 1) / spc;
//	"AHCIAtapiBlksRead(bd, dvd_buf, %d, %d);", blk2 / spc, n;
    AHCIAtapiBlksRead(bd, dvd_buf, blk2 / spc, n);
    if (bd->flags & BDF_READ_CACHE)
      DskCacheAdd(drive, dvd_buf, blk2, n * spc);
    MemCpy(buf, dvd_buf + (blk - blk2) << BLK_SIZE_BITS, cnt << BLK_SIZE_BITS);
    Free(dvd_buf);
  }
  else
    return FALSE;
  return TRUE;
}

Bool AHCIAtaRBlks(CDrv *drive, U8 *buf, I64 blk, I64 cnt)
{
  CBlkDev	*bd = drive->bd;
  if (bd->type == BDT_AHCI_SATA)
    AHCIAtaBlksRead(bd, buf, blk, cnt);
  else
    return FALSE;
  return TRUE;
}

Bool AHCIAtaWBlks(CDrv *drive, U8 *buf, I64 blk, I64 cnt)
{
  CBlkDev	*bd = drive->bd;
  AHCIAtaBlksWrite(bd, buf, blk, cnt);
  blkdev.write_cnt += cnt;
  return TRUE;
}
