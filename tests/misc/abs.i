/* run.config
   STDOPT: +"-remove-redundant-alarms"
   */


//@ requires \valid(p);
void main (int* p) {

  if (*p<0) *p=-*p;

  return;
}
