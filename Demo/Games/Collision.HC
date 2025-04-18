/*Uses $LK,"fixed-point",A="FI:::/Demo/Lectures/FixedPoint.HC"$ arithmetic
because it used to be faster than floating
point.	See $LK,"::/Demo/Lectures/FixedPoint.HC"$.

The decimal place is between
bits 31 and 32.
*/

#define BALLS_NUM	64
#define BALL_RADIUS	5

I64 ball_x[BALLS_NUM],ball_y[BALLS_NUM],
   ball_velocity_x[BALLS_NUM],ball_velocity_y[BALLS_NUM];

U0 DrawIt(CTask *,CDC *dc)
{
  I64 i;
  dc->color=RED;
  for (i=0;i<BALLS_NUM;i++)
    GrCircle(dc,ball_x[i].i32[1],ball_y[i].i32[1],BALL_RADIUS);
}

/****


$SP,"",BI=1$




Initial and final velocity vects
with normal and tangential components.
All masses are ident, so they
have been dropped from the equations.

Conservation of Momentum:

V1$SY,3$it$SY,0$+V2$SY,3$it$SY,0$=V1$SY,3$ft$SY,0$+V2$SY,3$ft$SY,0$

V1$SY,3$in$SY,0$+V2$SY,3$in$SY,0$=V1$SY,3$fn$SY,0$+V2$SY,3$fn$SY,0$

Conservation of Energy:

|V1$SY,3$i$SY,0$|$SY,-3$2$SY,0$+|V2$SY,3$i$SY,0$|$SY,-3$2$SY,0$=|V1$SY,3$f$SY,0$|$SY,-3$2$SY,0$+|V2$SY,3$f$SY,0$|$SY,-3$2$SY,0$
****/

U0 AnimateTask(I64)
{
  CTask *task=Fs->parent_task;
  I64 i,j,h,v,distdist,
        dia=(2*BALL_RADIUS)<<32,
        diadia=SqrI64(2*BALL_RADIUS)<<32,
        delta_x,delta_y,v_t1,v_n1,v_t2,v_n2;
  F64 dist;
  while (TRUE) {
    h=task->pix_width;
    v=task->pix_height;
    for (i=0;i<BALLS_NUM;i++) {
      ball_x[i]+=ball_velocity_x[i];
      ball_y[i]+=ball_velocity_y[i];
      if (ball_x[i]<BALL_RADIUS<<32) {
        ball_velocity_x[i]*=-1;
        ball_x[i]=BALL_RADIUS<<32;
      }
      if (ball_x[i]>=(h-BALL_RADIUS)<<32) {
        ball_velocity_x[i]*=-1;
        ball_x[i]=(h-BALL_RADIUS)<<32;
      }
      if (ball_y[i]<BALL_RADIUS<<32) {
        ball_velocity_y[i]*=-1;
        ball_y[i]=BALL_RADIUS<<32;
      }
      if (ball_y[i]>=(v-BALL_RADIUS)<<32) {
        ball_velocity_y[i]*=-1;
        ball_y[i]=(v-BALL_RADIUS)<<32;
      }
    }
    for (i=0;i<BALLS_NUM;i++) {
      for (j=i+1;j<BALLS_NUM;j++) {
        delta_x=ball_x[i]-ball_x[j];
        delta_y=ball_y[i]-ball_y[j];

        //We shift 16 because multiplying
        //two 32 shifted would yield 64 shifted
        //and we want a 32 shifted res.
        distdist=SqrI64(delta_x>>16)+SqrI64(delta_y>>16);

        //We work with square instead of sqrt
        //to avoid unnecessarily calculating
        //square heads (They are slow.)
        if (distdist && distdist<=diadia) {
	  dist=Sqrt(distdist); //shifted 16 bits
	  delta_x/=dist; //shifted 16
	  delta_y/=dist;

	  v_t1=(ball_velocity_x[i]>>16*delta_y-
	        ball_velocity_y[i]>>16*delta_x)>>16;
	  v_n1=(ball_velocity_x[i]>>16*delta_x+
	        ball_velocity_y[i]>>16*delta_y)>>16;
	  v_t2=(ball_velocity_x[j]>>16*delta_y-
	        ball_velocity_y[j]>>16*delta_x)>>16;
	  v_n2=(ball_velocity_x[j]>>16*delta_x+
	        ball_velocity_y[j]>>16*delta_y)>>16;

	  if (ball_velocity_x[i]>>16*ball_velocity_x[j]>>16+
	        ball_velocity_y[i]>>16*ball_velocity_y[j]>>16<=0) {
	    ball_velocity_x[i]= v_t1*delta_y-v_n1*delta_x;
	    ball_velocity_y[i]=-v_t1*delta_x-v_n1*delta_y;
	    ball_velocity_x[j]= v_t2*delta_y-v_n2*delta_x;
	    ball_velocity_y[j]=-v_t2*delta_x-v_n2*delta_y;
	  } else {
	    ball_velocity_x[i]= v_t1*delta_y+v_n2*delta_x;
	    ball_velocity_y[i]=-v_t1*delta_x+v_n2*delta_y;
	    ball_velocity_x[j]= v_t2*delta_y+v_n1*delta_x;
	    ball_velocity_y[j]=-v_t2*delta_x+v_n1*delta_y;
	  }

	  //Correct for overlap
	  dist=0x10000+(dia/0x10000-dist)/2;
	  ball_x[i]+=dist*delta_x;
	  ball_y[i]+=dist*delta_y;
	  ball_x[j]-=dist*delta_x;
	  ball_y[j]-=dist*delta_y;
        }
      }
    }
    Sleep(1);
  }
}

U0 Init()
{
  I64 i;
  for (i=0;i<BALLS_NUM;i++) {
    ball_x[i]=(RandU16%(Fs->pix_width-BALL_RADIUS*2)+BALL_RADIUS)<<32;
    ball_y[i]=(RandU16%(Fs->pix_height-BALL_RADIUS*2)+BALL_RADIUS)<<32;
    ball_velocity_x[i]=RandI32/4;
    ball_velocity_y[i]=RandI32/4;
  }
}

U0 Collision()
{
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  Init;
  Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  DocCursor;
  DocClear;
  Fs->draw_it=&DrawIt;
  GetChar;
  SettingsPop;
}

Collision;
        W      d   ����   �         r      �   ����r      �       �   ����v_t �      v_n  