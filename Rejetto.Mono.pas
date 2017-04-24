{
Copyright (C) 2002-2008 Massimo Melina (www.rejetto.com)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


This lib ensures only one instance of the software does run
}
unit Rejetto.Mono;

{$SCOPEDENUMS ON}

interface

uses
  Winapi.Windows, Winapi.Messages, Vcl.Forms, System.Classes, System.SysUtils;

type
  TMono = class
  private
    FMsgID: Thandle;
    FMaster: boolean;
    FError: string;
    FWorking: boolean;
    function hook(var msg: TMessage): boolean;
  public
    onSlaveParams: procedure(params: string);
    function init(id: string): boolean; // FALSE on error
    procedure sendParams();

    property error: string read FError;
    property master: boolean read FMaster;
    property working: boolean read FWorking;
  end;

var
  Mono: TMono;
  initialPath: string;

implementation

const
  // MSG_WHEREAREYOU = 1;
  //MSG_HEREIAM = 2;
  MSG_PARAMS = 3;

function atomToStr(atom: Tatom): string;
begin
  setlength(result, 5000);
  setlength(result, globalGetAtomName(atom, @result[1], length(result)));
end;

function TMono.hook(var msg: TMessage): boolean;
begin
  result := master and (msg.msg = FMsgID) and (msg.wparam = MSG_PARAMS);
  if not result or not assigned(onSlaveParams) then
    exit;
  msg.result := 1;
  onSlaveParams(atomToStr(msg.lparam));
  GlobalDeleteAtom(msg.lparam);
end;

function TMono.init(id: string): boolean;
begin
  result := FALSE;
  FMsgID := registerWindowMessage(pchar(id));
  application.HookMainWindow(hook);
  // the mutex is auto-released when the application terminates
  if createMutex(nil, True, pchar(id)) = 0 then
  begin
    setlength(FError, 1000);
    setlength(FError, FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM +
      FORMAT_MESSAGE_IGNORE_INSERTS, NIL, GetLastError(), 0, @FError[1],
      length(FError), NIL));
    exit;
  end;
  FMaster := GetLastError() <> ERROR_ALREADY_EXISTS;
  FWorking := True;
  result := True;
end;

procedure TMono.sendParams();
var
  s: string;
  i: integer;
begin
  s := initialPath + #13 + paramStr(0);
  for i := 1 to paramCount() do
    s := s + #13 + paramStr(i);
  // the master will delete the atom
  postMessage(HWND_BROADCAST, FMsgID, MSG_PARAMS, globalAddAtom(pchar(s)));
end;

initialization
  initialPath := getCurrentDir();
  Mono := TMono.create;

finalization
  Mono.free;

end.
