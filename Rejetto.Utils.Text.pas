unit Rejetto.Utils.Text;

interface

uses
  System.Types;

type
  Tnewline = (NL_UNK, NL_D, NL_A, NL_DA, NL_MIXED);

  TCharSet = set of char;
  PStringDynArray = ^TStringDynArray;

  TFastStringAppender = class
  protected
    buff: string;
    n: integer;
  public
    function Length(): integer;
    function Reset(): string;
    function Get(): string;
    function Append(s: string): integer;
  end;

  { split S in position where SS is found, the first part is returned
    the second part following SS is left in S }
function Chop(ss: string; var s: string): string; overload;
// same as before, but separator is I
function Chop(i: integer; var s: string): string; overload;
// same as before, but specifying separator length
function Chop(i, l: integer; var s: string): string; overload;
// same as chop(lineterminator, s)
function ChopLine(var s: string): string; overload;

function replace(var s: string; ss: string; start, upTo: integer): integer;

function substr(s: string; start: integer; upTo: integer = 0): string;
  inline; overload;
function substr(s: string; after: string): string; overload;

function xtpl(src: string; table: array of string): string;

// gets unicode code for specified character
function charToUnicode(c: char): dword;

function EscapeNL(s: string): string;
function UnescapeNL(s: string): string;
function HtmlEncode(s: string): string;

implementation

uses
  System.SysUtils, System.StrUtils, System.Math;

function Chop(i, l: integer; var s: string): string; overload;
begin
  if i = 0 then
  begin
    result := s;
    s := '';
    exit;
  end;
  result := copy(s, 1, i - 1);
  delete(s, 1, i - 1 + l);
end;

function Chop(ss: string; var s: string): string;
begin
  result := Chop(pos(ss, s), length(ss), s)
end;

function Chop(i: integer; var s: string): string;
begin
  result := Chop(i, 1, s)
end;

function ChopLine(var s: string): string;
begin
  result := chop(#10, s);
  if (result > '') and (result[length(result)] = #13) then
    setLength(result, length(result) - 1);
end;

function newlineType(s: string): Tnewline;
var
  d, a, l: integer;
begin
  d := pos(#13, s);
  a := pos(#10, s);
  if d = 0 then
    if a = 0 then
      result := NL_UNK
    else
      result := NL_A
  else if a = 0 then
    result := NL_D
  else if a = 1 then
    result := NL_MIXED
  else
  begin
    result := NL_MIXED;

    // search for an unpaired #10
    while (a > 0) and (s[a - 1] = #13) do
      a := posEx(#10, s, a + 1);
    if a > 0 then
      exit;

    // search for an unpaired #13
    l := length(s);
    while (d < l) and (s[d + 1] = #10) do
      d := posEx(#13, s, d + 1);
    if d > 0 then
      exit;

    // ok, all is paired
    result := NL_DA;
  end;
end;

function replace(var s: string; ss: string; start, upTo: integer): integer;
var
  common, oldL, surplus: integer;
begin
  oldL := upTo - start + 1;
  common := min(length(ss), oldL);
  Move(ss[1], s[start], common * SizeOf(char));
  surplus := oldL - length(ss);
  if surplus > 0 then
    delete(s, start + length(ss), surplus)
  else
    insert(copy(ss, common + 1, -surplus), s, start + common);
  result := -surplus;
end;

function substr(s: string; start: integer; upTo: integer = 0): string; inline;
var
  l: integer;
begin
  l := length(s);
  if start = 0 then
    inc(start)
  else if start < 0 then
    start := l + start + 1;
  if upTo <= 0 then
    upTo := l + upTo;
  result := copy(s, start, upTo - start + 1)
end;

function substr(s: string; after: string): string;
var
  i: integer;
begin
  i := pos(after, s);
  if i = 0 then
    result := ''
  else
    result := copy(s, i + length(after), MAXINT)
end;

function xtpl(src: string; table: array of string): string;
var
  i: integer;
begin
  i := 0;
  while i < length(table) do
  begin
    src := stringReplace(src, table[i], table[i + 1],
      [rfReplaceAll, rfIgnoreCase]);
    inc(i, 2);
  end;
  result := src;
end;

function HtmlEncode(s: string): string;
var
  i: integer;
  p: string;
  fs: TFastStringAppender;
begin
  fs := TFastStringAppender.create;
  try
    for i := 1 to length(s) do
    begin
      case s[i] of
        '&': p := '&amp;';
        '<': p := '&lt;';
        '>': p := '&gt;';
        '"': p := '&quot;';
        '''': p := '&#039;';
      else
        p := s[i];
      end;
      fs.Append(p);
    end;
    result := fs.Get();
  finally
    fs.free
  end;
end;

function charToUnicode(c: char): dword;
begin
  stringToWideChar(c, @result, 4)
end;

function EscapeNL(s: string): string;
begin
  s := replaceStr(s, '\', '\\');
  case newlineType(s) of
    NL_D:
      s := replaceStr(s, #13, '\n');
    NL_A:
      s := replaceStr(s, #10, '\n');
    NL_DA:
      s := replaceStr(s, #13#10, '\n');
    NL_MIXED:
      s := replaceStr(replaceStr(replaceStr(s, #13#10, '\n'), #13, '\n'), #10,
        '\n'); // bad case, we do our best
  end;
  result := s;
end;

function UnescapeNL(s: string): string;
var
  o, n: integer;
begin
  o := 1;
  while o <= length(s) do
  begin
    o := posEx('\n', s, o);
    if o = 0 then
      break;
    n := 1;
    while (o - n > 0) and (s[o - n] = '\') do
      inc(n);
    if odd(n) then
    begin
      s[o] := #13;
      s[o + 1] := #10;
    end;
    inc(o, 2);
  end;
  result := xtpl(s, ['\\', '\']);
end;

function TFastStringAppender.Length(): integer;
begin
  result := n
end;

function TFastStringAppender.Get(): string;
begin
  setLength(buff, n);
  result := buff;
end;

function TFastStringAppender.Reset(): string;
begin
  result := Get();
  buff := '';
  n := 0;
end;

function TFastStringAppender.Append(s: string): integer;
var
  ls, lb: integer;
begin
  ls := System.length(s);
  lb := System.length(buff);
  if n + ls > lb then
    setLength(buff, lb + ls + 20000);
  move(s[1], buff[n + 1], ls);
  inc(n, ls);
  result := n;
end;

end.
