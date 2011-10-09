/* run.config
   OPT: -rte -rte-precond -rte-print -journal-disable
*/

typedef int (*fptr)(int);

void g() { return; }

int f(int x) { return x; }
int h(int x) { return x; }

int main ()
{
  void (*fp1)();
  fptr fp2;
  fptr ma[2] = { &f, &h };
  
  fp1 = &g;
  fp2 = &f;

  (*fp1)();
  (*fp2)(3);
  (*ma[1])(5);
  return 0;  
}
