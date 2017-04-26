unit Rejetto.Math;

interface

function compare_(i1, i2: double): integer; overload;
function compare_(i1, i2: int64): integer; overload;
function compare_(i1, i2: integer): integer; overload;

function safeDiv(a, b: real; default: real = 0): real; overload;
function safeDiv(a, b: int64; default: int64 = 0): int64; overload;
function safeMod(a, b: int64; default: int64 = 0): int64;

implementation

function compare_(i1, i2: int64): integer; overload;
begin
  if i1 < i2 then
    result := -1
  else if i1 > i2 then
    result := 1
  else
    result := 0;
end;

function compare_(i1, i2: integer): integer; overload;
begin
  if i1 < i2 then
    result := -1
  else if i1 > i2 then
    result := 1
  else
    result := 0;
end;

function compare_(i1, i2: double): integer; overload;
begin
  if i1 < i2 then
    result := -1
  else if i1 > i2 then
    result := 1
  else
    result := 0;
end;

function safeMod(a, b: int64; default: int64 = 0): int64;
begin
  if b = 0 then
    result := default
  else
    result := a mod b;
end;

function safeDiv(a, b: int64; default: int64 = 0): int64; inline;
begin
  if b = 0 then
    result := default
  else
    result := a div b;
end;

function safeDiv(a, b: real; default: real = 0): real; inline;
begin
  if b = 0 then
    result := default
  else
    result := a / b;
end;

end.
