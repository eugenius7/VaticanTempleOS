I64 type_weights[OT_TYPES_NUM]= {0,30,30,15,30,30,1,1,1};

I64 mp_not_done_flags;
U0 MPDrawHoreb(CDC *dc2)
{
  CTask *task=dc2->win_task;
  CDC *dc=DCAlias(dc2,task);
  I64 i,j,dx,dy,dz,w=task->pix_width,h=task->pix_height+480-GR_HEIGHT,r[16],cx=w>>1;
  F64 s,m,a,x1,y1,x2,y2;
  Obj *tmpo;
  Mat4x4IdentEqu(r);
  Mat4x4RotY(r,-�);
  Mat4x4RotX(r,77*�/180);
  for (i=Gs->num; i<O_OBJS_NUM+O_PEBBLES_NUM; i+=mp_cnt)
  {
    tmpo=&objs[i];
    tmpo->x1=tmpo->x+vx;
    tmpo->y1=tmpo->y;
    tmpo->z1=tmpo->z+vz;
    Mat4x4MulXYZ(r,&tmpo->x1,&tmpo->y1,&tmpo->z1);
    if (tmpo->type==OT_SHEEP ||
        tmpo->type==OT_GOAT1 || tmpo->type==OT_GOAT2)
    {
      dx=100*tmpo->dx;
      dy=100*tmpo->dy;
      dz=100*tmpo->dz;
      Mat4x4MulXYZ(r,&dx,&dy,&dz);
      if (dx<0)
        tmpo->sym=TRUE;
      else
        tmpo->sym=FALSE;
    }
    if (tmpo->z1>=0)
    {
      s=100.0/(AbsI64(tmpo->z1)+50);
      if (tmpo->type)
      {
        Mat4x4IdentEqu(dc->r);
        Mat4x4Scale(dc->r,s*2);
        DCMat4x4Set(dc,dc->r);
        dc->flags|=DCF_TRANSFORMATION;
        if (tmpo->sym)
        {
          dc->flags|=DCF_SYMMETRY|DCF_JUST_MIRROR;
          DCSymmetrySet(dc,s*tmpo->x1+cx,s*tmpo->y1+h,
                        s*tmpo->x1+cx,s*tmpo->y1+h+10);
        }
        Sprite3B(dc,s*tmpo->x1+cx,s*tmpo->y1+h,tmpo->z1,imgs[tmpo->type]);
      }
      else
      {
        dc->flags&=~DCF_TRANSFORMATION;
        dc->color=pebble_colors[tmpo->num&3];
        GrPlot3(dc,s*tmpo->x1+cx,s*tmpo->y1+h,tmpo->z1);
      }
      dc->flags&=~(DCF_SYMMETRY|DCF_JUST_MIRROR);
      if (tmpo==&objs[O_BURNING_BUSH])  //draw burning bush
      {
        dc->x=s*tmpo->x1+cx;
        dc->y=s*tmpo->y1+h;
        dc->z=tmpo->z1;
        dc->thick=1;
        dc->color=winmgr.updates&15;
        for (j=0; j<45; j++)
        {
          m=Sqr(Rand);
          a=2*�*Rand;
          P2R(&x1,&y1,m,a);
          m=Sqr(Rand);
          a=2*�*Rand;
          P2R(&x2,&y2,m,a);
          GrLine3(dc,20*x1,20*y1-25,0,20*x2,20*y2-25,0);
        }
        if (SqrI64(s*tmpo->x1)+SqrI64(s*tmpo->y1)<300*300)
          horeb_done=TRUE;
      }
    }
  }
  dc->depth_buf=NULL;
  DCDel(dc);
  LBtr(&mp_not_done_flags,Gs->num);
}

U0 DrawHoreb(CTask *task,CDC *dc)
{
  I64 i,x,y,z,w=task->pix_width,h=task->pix_height,r[16],cx=w>>1,cy=h>>1;
  F64 s;
  Mat4x4IdentEqu(r);
  Mat4x4RotY(r,-�);
  Mat4x4RotX(r,77*�/180);
//Sun
  x=vx;
  y=0;
  z=1000000+vz;
  Mat4x4MulXYZ(r,&x,&y,&z);
  s=100.0/(AbsI64(z)+50);
  if (y<0)
  {
    dc->color=BROWN;
    GrCircle(dc,s*x+cx,15,15);
    dc->color=YELLOW;
    GrFloodFill(dc,s*x+cx,15);
  }
  DCDepthBufAlloc(dc);
  mp_not_done_flags=1<<mp_cnt-1;
  for (i=0; i<mp_cnt; i++)
    JobQue(&MPDrawHoreb,dc,i);
  while (mp_not_done_flags)
    Yield;
  if (Blink)
  {
    dc->color=LTRED;
    GrPrint(dc,cx-21*FONT_WIDTH/2,cy-FONT_HEIGHT/2,"Find the Burning Bush.");
  }
}
