unit Rejetto.Utils.Registry;

interface

uses
  Winapi.Windows,
  System.Win.Registry;

function loadregistry(key, value: string; root: HKEY = 0): string;
function saveregistry(key, value, data: string; root: HKEY = 0): boolean;
function deleteRegistry(key, value: string; root: HKEY = 0): boolean; overload;
function deleteRegistry(key: string; root: HKEY = 0): boolean; overload;

implementation

uses
  System.SysUtils,
  System.Classes;

function loadregistry(key, value: string; root: HKEY = 0): string;
begin
  result := '';
  with Tregistry.create do
    try
      try
        if root > 0 then
          rootKey := root;
        if openKey(key, FALSE) then
        begin
          result := readString(value);
          closeKey();
        end;
      finally
        free
      end
    except
    end
end;

function saveregistry(key, value, data: string; root: HKEY = 0): boolean;
begin
  result := FALSE;
  with Tregistry.create do
    try
      if root > 0 then
        rootKey := root;
      try
        createKey(key);
        if openKey(key, FALSE) then
        begin
          WriteString(value, data);
          closeKey;
          result := TRUE;
        end;
      finally
        free
      end
    except
    end;
end;

function deleteRegistry(key, value: string; root: HKEY = 0): boolean; overload;
var
  reg: Tregistry;
begin
  reg := Tregistry.create;
  if root > 0 then
    reg.rootKey := root;
  result := reg.openKey(key, FALSE) and reg.DeleteValue(value);
  reg.free
end;

function deleteRegistry(key: string; root: HKEY = 0): boolean; overload;
var
  reg: Tregistry;
  ss: TstringList;
  i: integer;
  deleteIt: boolean;
begin
  reg := Tregistry.create;
  if root > 0 then
    reg.rootKey := root;
  result := reg.DeleteKey(key);
  // delete also parent keys, if empty
  ss := TstringList.create;
  while key > '' do
  begin
    i := LastDelimiter('\', key);
    if i = 0 then
      break;
    SetLength(key, i - 1);
    if not reg.OpenKeyReadOnly(key) then
      break;
    reg.GetValueNames(ss);
    deleteIt := (ss.count = 0) and not reg.HasSubKeys;
    reg.closeKey;
    if deleteIt then
      reg.DeleteKey(key)
    else
      break;
  end;
  ss.free;
  reg.free
end;

end.
