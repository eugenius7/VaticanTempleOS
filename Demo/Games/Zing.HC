I64 box_x_min,box_x_max,box_y_min,box_y_max;

class Arrow
{
  Arrow *next,*last;
  F64 x,y,dx,dy;
} head;

   $SP,"<1>",BI=1$

Bool bow_drawn;
F64 bow_x,bow_y,bow_�;

U0 DrawIt(CTask *task,CDC *dc)
{
  F64 �,x,y,dx,dy,
        str_w,str_h,draw_len;
  Arrow *tmpa;
  CD3I32 ctrl[5];
  dc->color=RED;
  GrBorder(dc,box_x_min,box_y_min,box_x_max,box_y_max);

  x=ClampI64(ms.pos.x-task->pix_left-task->scroll_x,box_x_min,box_x_max);
  y=ClampI64(ms.pos.y-task->pix_top-task->scroll_y, box_y_min,box_y_max);
  dx=bow_x-x;
  dy=bow_y-y;

  if (bow_drawn && (dx|dy))
    bow_�=Arg(dx,dy);
  else {
    bow_x=x;
    bow_y=y;
  }

  draw_len=Sqrt(dx*dx+dy*dy);
  str_w=draw_len/3;
  str_h=Sqrt(60*60-str_w*str_w);

  dc->color=BLACK;
  GrLine(dc,x-str_h/2*Cos(bow_�+�/2)+str_w*Cos(bow_�),
        y-str_h/2*Sin(bow_�+�/2)+str_w*Sin(bow_�),
        x,y);
  GrLine(dc,x+str_h/2*Cos(bow_�+�/2)+str_w*Cos(bow_�),
        y+str_h/2*Sin(bow_�+�/2)+str_w*Sin(bow_�),
        x,y);

  MemSet(ctrl,0,sizeof(ctrl));
  ctrl[0].x=x-str_h/2*Cos(bow_�+�/2)+str_w*Cos(bow_�);
  ctrl[0].y=y-str_h/2*Sin(bow_�+�/2)+str_w*Sin(bow_�);
  ctrl[1].x=x-0.75*str_h/2*Cos(bow_�+�/2)+draw_len/2*Cos(bow_�)+
        str_w*Cos(bow_�);
  ctrl[1].y=y-0.75*str_h/2*Sin(bow_�+�/2)+draw_len/2*Sin(bow_�)+
        str_w*Sin(bow_�);
  ctrl[2].x=x+draw_len/2*Cos(bow_�)+str_w*Cos(bow_�);
  ctrl[2].y=y+draw_len/2*Sin(bow_�)+str_w*Sin(bow_�);
  ctrl[3].x=x+0.75*str_h/2*Cos(bow_�+�/2)+draw_len/2*Cos(bow_�)+
        str_w*Cos(bow_�);
  ctrl[3].y=y+0.75*str_h/2*Sin(bow_�+�/2)+draw_len/2*Sin(bow_�)+
        str_w*Sin(bow_�);
  ctrl[4].x=x+str_h/2*Cos(bow_�+�/2)+str_w*Cos(bow_�);
  ctrl[4].y=y+str_h/2*Sin(bow_�+�/2)+str_w*Sin(bow_�);

  dc->color=BROWN;
  dc->thick=2;
  Gr2BSpline3(dc,ctrl,5);
  dc->thick=1;

  if (bow_drawn)
    Sprite3ZB(dc,x,y,0,$IB,"<1>",BI=1$,bow_�);

  tmpa=head.next;
  while (tmpa!=&head) {
    �=Arg(tmpa->dx,tmpa->dy);
    Sprite3ZB(dc,tmpa->x,tmpa->y,0,$IB,"<1>",BI=1$,�);
    tmpa=tmpa->next;
  }
}

#define ANIMATE_SLEEP_MS	10

U0 AnimateTask(I64)
{
  I64 x,y;
  Arrow *tmpa,*tmpa1;
  F64 dt,t0=tS;
  while (TRUE) {
    dt=tS-t0;
    t0=tS;

    x=ClampI64(ms.pos.x-Fs->parent_task->pix_left-Fs->parent_task->scroll_x,
	  box_x_min,box_x_max)+Fs->parent_task->pix_left+
	  Fs->parent_task->scroll_x;
    y=ClampI64(ms.pos.y-Fs->parent_task->pix_top-Fs->parent_task->scroll_y,
	  box_y_min,box_y_max)+Fs->parent_task->pix_top+
	  Fs->parent_task->scroll_y;
    if (ms.pos.x!=x || ms.pos.y!=y)
      MsSet(x,y);

    tmpa=head.next;
    while (tmpa!=&head) {
      tmpa1=tmpa->next;
      tmpa->x+=tmpa->dx*dt;
      tmpa->y+=tmpa->dy*dt;
      if (!(-Fs->parent_task->scroll_x<=
	    tmpa->x<Fs->parent_task->pix_width-Fs->parent_task->scroll_x) ||
	    !(-Fs->parent_task->scroll_y<=
	    tmpa->y<Fs->parent_task->pix_height-Fs->parent_task->scroll_y)) {
        QueRem(tmpa);
        Free(tmpa);
      }
      tmpa=tmpa1;
    }
    Refresh;
  }
}

U0 Init()
{
  I64 w=Fs->pix_width,
        h=Fs->pix_height;
  QueInit(&head);
  bow_drawn=FALSE;
  box_x_min=7*w/16;
  box_y_min=6*h/8;
  box_x_max=9*w/16;
  box_y_max=7*h/8;
  bow_�=-�/2;
  bow_x=(box_x_min+box_x_max)/2;
  bow_y=(box_y_min+box_y_max)/2;
  MsSet(bow_x+Fs->pix_left+Fs->scroll_x,
        bow_y+Fs->pix_top+Fs->scroll_y);
}

U0 CleanUp()
{
  QueDel(&head,TRUE);
}

U0 Zing()
{
  I64 arg1,arg2;
  Arrow *tmpa;
  MenuPush(
        "File {"
        "  Abort(,CH_SHIFT_ESC);"
        "  Exit(,CH_ESC);"
        "}"
        "Play {"
        "  Restart(,'\n');"
        "}"
        );
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;

  Init;
  Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  Fs->draw_it=&DrawIt;
  Fs->win_inhibit=WIG_TASK_DFT-WIF_SELF_FOCUS-WIF_SELF_GRAB_SCROLL;
  try {
    while (TRUE)
      switch (GetMsg(&arg1,&arg2,
	    1<<MSG_KEY_DOWN|1<<MSG_MS_L_DOWN|1<<MSG_MS_L_UP)) {
        case MSG_KEY_DOWN:
	  switch (arg1) {
	    case '\n':
	      CleanUp;
	      Init;
	      break;
	    case CH_ESC:
	    case CH_SHIFT_ESC:
	      goto zi_done;
	  }
	  break;
        case MSG_MS_L_DOWN:
	  bow_x=arg1;
	  bow_y=arg2;
	  bow_drawn=TRUE;
	  break;
        case MSG_MS_L_UP:
	  if(arg1-bow_x || arg2-bow_y) {
	    tmpa=MAlloc(sizeof(Arrow));
	    tmpa->dx=10.0*(bow_x-arg1);
	    tmpa->dy=10.0*(bow_y-arg2);
	    tmpa->x=arg1;
	    tmpa->y=arg2;
	    QueIns(tmpa,head.last);
	    Noise(50,110,114);
	  }
	  bow_drawn=FALSE;
	  break;
      }
zi_done:
    GetMsg(,,1<<MSG_KEY_UP);
  } catch
    PutExcept;
  SettingsPop;
  CleanUp;
  MenuPop;
}

Zing;
        �      
        1        
5       2   ����
2   ����2      
2      5       
            
      ����   
����          
    ������������
��������   ����
   ����   ����                     ����   ���� 