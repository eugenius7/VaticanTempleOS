extern U0 ACDDef(I64 n,CTask *parent=NULL);
extern U0 ACDDefsPut(CDoc *doc=NULL,U8 *st,I64 num=-1);
extern U0 ACDFillin(I64 n);
extern U0 ACFillIn(I64 n);
extern U0 ACMan(I64 n,CTask *parent_task=NULL);
extern I64 AdamFile(U8 *filename,Bool warn_ext=TRUE);
extern Bool AutoComplete(Bool val=OFF);
extern I64 BMPWrite(U8 *filename,CDC *dc,I64 bits=4);
extern U0 ClipDel();
extern CCtrl *CtrlFindUnique(CTask *haystack_task,I64 needle_type);
extern Bool CtrlInside(CCtrl *c,I64 x,I64 y);
extern U8 *DC2Sprite(CDC *tmpb);
extern U0 DocBinDel(CDoc *doc,CDocBin *b);
extern U0 DocBinsValidate(CDoc *doc);
extern U0 DocBottom(CDoc *doc=NULL);
extern U0 DocBMP(CDoc *doc=NULL,U8 *filename,
    Bool dither_probability=FALSE,Bool use_ms_paint_palette=FALSE);
extern U0 DocCenter(CDoc *doc=NULL,I64 recalc_flags=RECALCt_NORMAL);
extern U0 DocClear(CDoc *doc=NULL,Bool clear_holds=FALSE);
extern Bool DocCursor(Bool show=OFF,CDoc *doc=NULL);
extern U0 DocD(U8 *buf,I64 cnt=0x80);
extern U0 DocDataFmt(CDoc *doc,CDocEntry *doc_e,I64 d=DOCM_CANCEL);
extern U0 DocDel(CDoc *doc);
extern CDoc *DocDisplay(CTask *task=NULL);
extern U0 DocDump(CDoc *doc,I64 uS_delay=0);
extern CDocEntry *DocEntryCopy(CDoc *doc,CDocEntry *doc_e);
extern U0 DocEntryDel(CDoc *doc,CDocEntry *doc_e);
extern Bool DocForm(U8 *_d,U8 *class_name=lastclass,
    I64 dof_flags=0,U8 *header=NULL,U8 *footer=NULL);
extern U0 DocHelpIdx(CDoc *doc,U8 *idx);
extern Bool DocHighlightCursor(Bool show=OFF,CDoc *doc=NULL);
extern U0 DocInsDoc(CDoc *doc=NULL,CDoc *doc2);
extern U0 DocInsEntry(CDoc *doc,CDocEntry *doc_e);
extern Bool DocLock(CDoc *doc);
extern I64 DocMax(I64 i=I64_MAX);
extern CDoc *DocNew(U8 *filename=NULL,CTask *task=NULL);
extern CDocEntry *DocPrint(CDoc *doc=NULL,U8 *fmt,...);
extern CDoc *DocPut(CTask *task=NULL);
extern CDoc *DocRead(U8 *name=NULL,I64 flags=0);
extern Bool DocRecalc(CDoc *doc,I64 recalc_flags=RECALCt_NORMAL);
extern U0 DocRst(CDoc *doc,Bool is_old);
extern CDocEntry *DocSprite(CDoc *doc=NULL,U8 *elems,U8 *fmt=NULL);
extern U0 DocTop(CDoc *doc=NULL);
extern Bool DocUnlock(CDoc *doc);
extern U0 DocUpdateTaskDocs(CTask *task);
extern U0 DrawCtrls(CTask *task);
extern Bool Ed(U8 *link_st,I64 edf_dof_flags=0);
extern U0 EdCodeTools(CDoc *doc);
extern U8 *EdSprite(I64 bin_num);
extern I64 ExeDoc(CDoc *doc,I64 ccf_flags=0);
extern I64 FindWiz();
extern I64 GetI64(U8 *msg=NULL,I64 dft=0,I64 lo=I64_MIN,I64 hi=I64_MAX);
extern Bool GrPlot0(CDC *dc,I64 x,I64 y);
extern I64 ISO9660ISO(U8 *_filename=NULL,U8 *src_files_find_mask,
    U8 *fu_flags=NULL,U8 *_stage2_filename=NULL);
extern CMenuEntry *MenuEntryFind(CMenu *haystack_menu,U8 *needle_full_name);
extern CMenu *MenuFilePush(U8 *filename);
extern U0 MenuPop();
extern CMenu *MenuPush(U8 *st);
extern U8 Mount(Bool caller_is_prtdsk=FALSE,Bool just_ide=FALSE);
extern CTask *Noise(I64 mS,F64 min_ona,F64 max_ona);
extern Bool Plain(U8 *filename,I64 edf_dof_flags=0);
extern Bool PopUpCancelOk(U8 *header=NULL,U8 *footer=NULL);
extern I64 PopUpColor(U8 *header=NULL,
    Bool allow_transparent=TRUE,Bool allow_dft=TRUE);
extern I64 PopUpColorDither(U8 *header=NULL);
extern I64 PopUpColorLighting(U8 *header=NULL);
extern I64 PopUpFile(U8 *filename,
    Bool warn_ext=TRUE,CTask *parent=NULL,CTask **_pu_task=NULL);
extern Bool PopUpForm(U8 *_d,U8 *class_name=lastclass,
    I64 dof_flags=DOF_SIZE_MIN,U8 *header=NULL,U8 *footer=NULL);
extern I64 PopUpGetI64(U8 *msg,I64 dft,I64 lo=I64_MIN,I64 hi=I64_MAX);
extern U8 *PopUpGetStr(U8 *header=NULL);
extern I64 PopUpMenu(CDoc *doc,I64 dof_flags=0, U8 *title=NULL);
extern Bool PopUpNoYes(U8 *header=NULL,U8 *footer=NULL);
extern Bool PopUpOk(U8 *header=NULL,U8 *footer=NULL);
extern I64 PopUpRangeI64(I64 lo,I64 hi,I64 step=1,U8 *header=NULL,U8 *footer=NULL);
extern Bool PopUpTransform(I64 *r);
extern CPCIDev	*PCIDevFind(U16 class_code=NULL, U16 sub_code=NULL, U16 vendor_id=NULL,
    U16 device_id=NULL, U8 _bus=0xFF, U8 _dev=0xFF, U8 _fun=0xFF);
extern I64 RedSeaISO(U8 *_iso_filename=NULL,U8 *_src_dir,
    U8 *_stage2_filename=NULL);
extern U0 Refresh(I64 cnt=1,Bool force=FALSE);
extern U0 RegOneTimePopUp(I64 flag_num,U8 *msg);
extern Bool RegWrite(U8 *path,U8 *fmt,...);
extern I64 SATARep(I64 bd_type=BDT_NULL, I64 *first_hdd=NULL);

extern U0 SettingsPop(CTask *task=NULL,I64 flags=0);
extern CTaskSettings *SettingsPush(CTask *task=NULL,I64 flags=0);
extern U0 TemplateCtrlSlider(CDoc *doc);
extern Bool View();
extern U0 ViewAnglesDel(CTask *task=NULL);
extern CCtrl *ViewAnglesNew(CTask *task=NULL);
extern Bool WinBorder(Bool val=OFF,CTask *task=NULL);
extern CDoc *WinCursorPosSet(CTask *task,I64 msx,I64 msy,Bool set_cursor=TRUE);
extern Bool WinHorz(I64 left,I64 right,CTask *task=NULL);
extern U0 WinMax(CTask *task=NULL);
extern U0 WinScrollNull(CTask *task,CD3I64 *s);
extern U0 WinScrollRestore(CTask *task,CD3I64 *s);
extern U0 WinScrollsInit(CTask *task);
extern I64 WinToTop(CTask *task=NULL,Bool update_z_buf=TRUE);
extern Bool WinVert(I64 top,I64 bottom,CTask *task=NULL);
extern CWinMgrGlbls winmgr;
extern U0 InUntilKey(I64 scan_code,I64 sc_mask=0xFF|SCF_SHIFT|SCF_CTRL|SCF_ALT,
    I64 timeout=-1);
extern I64 InGetChar(...);
extern I64 InUntilChar(...);
extern Bool BootMHDIns(U8 drv_let,U8 *drv_lst=NULL);
extern I64 Hypervisor();
extern U0 PCILookUpDevs();
extern U0 PCILookUpDev(I64 vendor, I64 dev);
extern Bool PciFindByID(U16 vendor_id, U16 device_id, U16 class_code=NULL, U16 sub_code=NULL,
                 I64* bus_out=NULL, I64* dev_out=NULL, I64* fun_out=NULL);

