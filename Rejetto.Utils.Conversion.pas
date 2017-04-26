unit Rejetto.Utils.Conversion;

interface

uses
  System.Types,
  Rejetto.Utils.Text;

function boolToPtr(b: boolean): pointer;
function strToCharset(s: string): TcharSet;
function rectToStr(r: Trect): string;
function strToRect(s: string): Trect;
function dt_(s: string): Tdatetime;
function int_(s: string): integer;
function strToUInt(s: string): integer;
function elapsedToStr(t: Tdatetime): string;
function dateToHTTP(gmtTime: Tdatetime): string; overload;
function dateToHTTP(filename: string): string; overload;
function toSA(a: array of string): TstringDynArray;

implementation

uses
  System.SysUtils, System.DateUtils,
  Rejetto.Utils, Rejetto.Consts;

function boolToPtr(b: boolean): pointer;
begin
  result := if_(b, PTR1, NIL)
end;

function strToCharset(s: string): TcharSet;
var
  i: integer;
begin
  result := [];
  for i := 1 to length(s) do
    include(result, ansichar(s[i]));
end;

function rectToStr(r: Trect): string;
begin
  result := format('%d,%d,%d,%d', [r.left, r.top, r.right, r.bottom])
end;

function strToRect(s: string): Trect;
begin
  result.left := strToInt(chop(',', s));
  result.top := strToInt(chop(',', s));
  result.right := strToInt(chop(',', s));
  result.bottom := strToInt(chop(',', s));
end;

// converts from string[4] to integer
function int_(s: string): integer;
begin
  result := Pinteger(@s[1])^
end;

// converts from string[8] to datetime
function dt_(s: string): Tdatetime;
begin
  result := Pdatetime(@s[1])^
end;

function strToUInt(s: string): integer;
begin
  s := trim(s);
  if s = '' then
    result := 0
  else
    result := strToInt(s);
  if result < 0 then
    raise Exception.create('strToUInt: Signed value not accepted');
end;

function elapsedToStr(t: Tdatetime): string;
var
  sec: integer;
begin
  sec := trunc(t * SECONDS);
  result := format('%d:%.2d:%.2d', [sec div 3600, sec div 60 mod 60,
    sec mod 60]);
end;

function dateToHTTP(filename: string): string; overload;
begin
  result := dateToHTTP(getMtimeUTC(filename))
end;

function dateToHTTP(gmtTime: Tdatetime): string; overload;
begin
  result := formatDateTime('"' + DOW2STR[dayOfWeek(gmtTime)] + '," dd "' +
    MONTH2STR[monthOf(gmtTime)] + '" yyyy hh":"nn":"ss "GMT"', gmtTime);
end;

function toSA(a: array of string): TstringDynArray;
// this is just to have a way to typecast
begin
  result := NIL;
  addArray(result, a);
end;

end.
