<cfscript>
// Dense code file with multiple blocks on same lines for testing position-based filtering
function test() { var a = 1; var b = 2; if (a > 0) { b++; } else { b--; } return a + b; }
total = 0; for (i = 1; i <= 3; i++) { total += i; } x = 0; while (x < 5) { x++; }
try { testVal = "test"; } catch (any e) { void = e; } finally { void = "cleanup"; }
a = 1; b = 2; c = 3; d = a + b + c; e = d * 2; f = e / 3; g = f - 1;
condition = true; other = false; third = true; if (condition) { a = 1; } if (other) { b = 2; } if (third) { c = 3; }
list = [1,2,3,4,5,6,7,8,9,10]; filtered = list.filter(function(n) { return n > 5; }); mapped = filtered.map(function(n) { return n * 2; });
val = 2; result = ""; switch(val) { case 1: result = "one"; break; case 2: result = "two"; break; default: result = "other"; }
arr = []; for (j = 0; j < 10; j++) { arr[j+1] = j * j; if (j % 2 == 0) { arr[j+1] *= 2; } }
function nested() { function inner() { function deep() { return "deep"; } return deep(); } return inner(); }
y = 1; z = 2; w = 3; x = y > 0 ? z : w; q = 0; r = 5; p = q ?: r; n = 10; m = n > 0 ? n * 2 : n / 2;
</cfscript>