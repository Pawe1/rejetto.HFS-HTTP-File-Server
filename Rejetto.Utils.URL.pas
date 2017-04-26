unit Rejetto.Utils.URL;

interface

uses
  System.Classes;

function decodeURL(url: string; utf8: boolean = TRUE): string;
function encodeURL(url: string; nonascii: boolean = TRUE;
  spaces: boolean = TRUE; unicode: boolean = FALSE): string;
procedure urlToStrings(s: string; sl: Tstrings);

implementation

uses
  System.SysUtils, System.StrUtils,
  Rejetto.Utils, Rejetto.Utils.Text;

function decodeURL(url: string; utf8: boolean = TRUE): string;
var
  i, l: integer;
  c: char;
begin
  setLength(result, length(url));
  l := 0;
  i := 1;
  while i <= length(url) do
  begin
    if (url[i] = '%') and (i + 2 <= length(url)) then
      try
        c := char(strToInt('$' + url[i + 1] + url[i + 2]));
        inc(i, 2); // three chars for one
      except
        c := url[i]
      end
    else
      c := url[i];

    inc(i);
    inc(l);
    result[l] := c;
  end;
  setLength(result, l);
  if utf8 then
  begin
    url := utf8ToAnsi(result);
    // if the string is not UTF8 compliant, the result is empty
    if url > '' then
      result := url;
  end;
end;

function encodeURL(url: string; nonascii: boolean = TRUE;
  spaces: boolean = TRUE; unicode: boolean = FALSE): string;
var
  i: integer;
  encodePerc, encodeUni: set of char;
begin
  result := '';
  encodeUni := [];
  if nonascii then
    encodeUni := [#128 .. #255];
  encodePerc := [#0 .. #31, '#', '%', '?', '"', '''', '&', '<', '>', ':'];
  // actually ':' needs encoding only in relative url
  if spaces then
    include(encodePerc, ' ');
  if not unicode then
  begin
    encodePerc := encodePerc + encodeUni;
    encodeUni := [];
  end;
  for i := 1 to length(url) do
    if url[i] in encodePerc then
      result := result + '%' + intToHex(ord(url[i]), 2)
    else if url[i] in encodeUni then
      result := result + '&#' + intToStr(charToUnicode(url[i])) + ';'
    else
      result := result + url[i];
end;

procedure urlToStrings(s: string; sl: Tstrings);
var
  i, l, p: integer;
  t: string;
begin
  i := 1;
  l := length(s);
  while i <= l do
  begin
    p := posEx('&', s, i);
    t := decodeURL(xtpl(substr(s, i, if_(p = 0, 0, p - 1)), ['+', ' ']), FALSE);
    // TODO should we instead try to decode utf-8? doing so may affect calls to {.force ansi.} in the template
    sl.add(t);
    if p = 0 then
      exit;
    i := p + 1;
  end;
end;

end.
