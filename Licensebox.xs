#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
typedef struct lb_client lb_client;
typedef struct {void *context;void(*on_sign_in)(void*,const char*,const char*);double(*clock)(void*);int(*machine_binding)(void*,char*,size_t);int(*cancelled)(void*);} lb_callbacks;
extern int lb_client_create_json(const char*,const lb_callbacks*,lb_client**);
extern int lb_client_call_json(lb_client*,const char*,const char*,char**);
extern void lb_client_destroy(lb_client*);extern void lb_free(void*);
extern const char *lb_result_code(int);extern const char *lb_error_code(lb_client*);extern const char *lb_error_message(lb_client*);
extern int lb_derive_binding(const char*,const char*,const char*,char*,size_t);
extern int lb_native_binding(const char*,char*,size_t);
extern int lb_verify_lease_json(const char*,const char*,const char*,double,char**);
typedef struct {lb_client *client;SV *sign,*clock,*binding,*cancel;int failed,busy;} host;
static void raise_error(const char *code,const char *message){dTHX;HV *hv=newHV();hv_stores(hv,"code",newSVpv(code,0));hv_stores(hv,"message",newSVpv(message,0));SV *e=newRV_noinc((SV*)hv);sv_bless(e,gv_stashpv("Licensebox::Error",GV_ADD));croak_sv(e);}
static void result_error(int r,lb_client*c){const char *code=lb_result_code(r),*message=code;if(c&&strcmp(code,"invalid_argument")){const char *saved=lb_error_code(c);if(strcmp(saved,"ok"))code=saved;message=lb_error_message(c);}raise_error(code,message);}
static SV *invoke(host*h,SV*cb,const char*u,const char*c){dTHX;dSP;SV *v=NULL;if(!cb)return NULL;ENTER;SAVETMPS;PUSHMARK(SP);if(u){XPUSHs(sv_2mortal(newSVpv(u,0)));XPUSHs(sv_2mortal(newSVpv(c,0)));}PUTBACK;int n=call_sv(cb,G_SCALAR|G_EVAL);SPAGAIN;SV*returned=n?POPs:NULL;if(SvTRUE(ERRSV)){h->failed=1;sv_setsv(ERRSV,&PL_sv_undef);}else if(returned)v=newSVsv(returned);PUTBACK;FREETMPS;LEAVE;return v;}
static void sign_cb(void*p,const char*u,const char*c){dTHX;SV*v=invoke(p,((host*)p)->sign,u,c);if(v)SvREFCNT_dec(v);}
static double clock_cb(void*p){dTHX;host*h=p;SV*v=invoke(h,h->clock,NULL,NULL);if(!v)return 0;if(!SvOK(v)||SvROK(v)||!looks_like_number(v)){h->failed=1;SvREFCNT_dec(v);return 0;}double n=SvNV(v);SvREFCNT_dec(v);if(!isfinite(n)){h->failed=1;return 0;}return n;}
static int binding_cb(void*p,char*out,size_t n){dTHX;host*h=p;SV*v=invoke(h,h->binding,NULL,NULL);if(!v)return 1;if(!SvOK(v)||SvROK(v)){h->failed=1;SvREFCNT_dec(v);return 1;}STRLEN len;const char*s=SvPVutf8(v,len);int bad=memchr(s,0,len)!=NULL||len>=n;if(!bad){memcpy(out,s,len);out[len]=0;}else h->failed=1;SvREFCNT_dec(v);return bad;}
static int cancel_cb(void*p){dTHX;host*h=p;if(h->failed)return 1;SV*v=invoke(h,h->cancel,NULL,NULL);if(v&&SvROK(v))h->failed=1;int r=h->failed||(v&&!SvROK(v)&&SvTRUE(v));if(v)SvREFCNT_dec(v);return r;}
static SV *hook(HV*h,const char*name){dTHX;SV**p=hv_fetch(h,name,strlen(name),0);return p&&SvOK(*p)?newSVsv(*p):NULL;}
static void dispose(host*h){dTHX;if(!h)return;if(h->client)lb_client_destroy(h->client);SvREFCNT_dec(h->sign);SvREFCNT_dec(h->clock);SvREFCNT_dec(h->binding);SvREFCNT_dec(h->cancel);free(h);}
MODULE = Licensebox PACKAGE = Licensebox::Native
PROTOTYPES: DISABLE
UV
_create(options,hooks)
    const char *options
    HV *hooks
  CODE:
    host*h=calloc(1,sizeof(*h));if(!h)croak("allocation failed");
    h->sign=hook(hooks,"on_sign_in");h->clock=hook(hooks,"clock");h->binding=hook(hooks,"machine_binding");h->cancel=hook(hooks,"cancelled");
    lb_callbacks cb={h,h->sign?sign_cb:NULL,h->clock?clock_cb:NULL,h->binding?binding_cb:NULL,cancel_cb};
    int r=lb_client_create_json(options,&cb,&h->client);
    if(r||h->failed){int failed=h->failed;dispose(h);if(failed)raise_error("callback_error","application callback failed");result_error(r,NULL);}
    RETVAL=PTR2UV(h);
  OUTPUT: RETVAL

SV *
_call(ptr,operation,args)
    UV ptr
    const char *operation
    const char *args
  CODE:
    host*h=INT2PTR(host*,ptr);if(!h||h->busy)raise_error("invalid_argument","closed or reentered client");
    h->busy=1;char*out=NULL;int r=lb_client_call_json(h->client,operation,args,&out);h->busy=0;
    if(r||h->failed){lb_free(out);if(h->failed){h->failed=0;raise_error("callback_error","application callback failed");}result_error(r,h->client);}
    if(!out)raise_error("protocol_error","missing JSON output");RETVAL=newSVpv(out,0);lb_free(out);
  OUTPUT: RETVAL

void
_close(ptr)
    UV ptr
  CODE:
    host*h=INT2PTR(host*,ptr);if(h&&h->busy)raise_error("invalid_argument","callback reentry");dispose(h);

SV *
_derive(product,source,raw)
    const char *product
    const char *source
    const char *raw
  CODE:
    char out[128];int r=lb_derive_binding(product,source,raw,out,sizeof(out));if(r)result_error(r,NULL);RETVAL=newSVpv(out,0);
  OUTPUT: RETVAL

SV *
_native(product)
    const char *product
  CODE:
    char out[128];int r=lb_native_binding(product,out,sizeof(out));if(r)result_error(r,NULL);RETVAL=newSVpv(out,0);
  OUTPUT: RETVAL

SV *
_verify(token,product,keys,now)
    const char *token
    const char *product
    const char *keys
    double now
  CODE:
    char*out=NULL;int r=lb_verify_lease_json(token,product,keys,now,&out);if(r){lb_free(out);result_error(r,NULL);}if(!out)raise_error("protocol_error","missing JSON output");RETVAL=newSVpv(out,0);lb_free(out);
  OUTPUT: RETVAL
