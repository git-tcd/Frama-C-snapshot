/* run.config
   OPT: -memory-footprint 1 -val -deps -out -input -journal-disable
   OPT: -memory-footprint 1 -val -deps -out -input -journal-disable -machdep ppc_32
*/
int G= 77;
int GG;

struct A { int x; int y; };
struct B { int z; int t; };

struct A t[4];
struct A tt[5];

int g(struct A s)
{
  Frama_C_show_each_G(s);
  return s.y; // (*((struct B*)(&t[1]))).t;
  
}

struct A create_A() {
  struct A r={0,0};
  r.x = 1;
//  r.y = 2;
  Frama_C_show_each_GG(r);
  return r;
}

int main(void)
{
  int i = 2 - 1;
  t[1].y = G;
  GG = g(tt[i]);
  struct A init = create_A();
  return g(t[i]);
}
