{
Copyright (C) 2002-2014  Massimo Melina (www.rejetto.com)

This file is part of HFS ~ HTTP File Server.

    HFS is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    HFS is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with HSG; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}
{$INCLUDE defs.inc }
{$SetPEOptFlags $100 } //IMAGE_DLLCHARACTERISTICS_NX_COMPAT
program hfs;

uses
  FastMM4,
  {$IFDEF EX_DEBUG}
  ftmExceptionForm,
  {$ENDIF }
  Rejetto.Mono in 'Rejetto.Mono.pas',
  Vcl.Forms,
  Winapi.Windows,
  System.Types,
  Rejetto.HTTPServer in 'Rejetto.HTTPServer.pas',
  System.SysUtils,
  main in 'main.pas' {mainFrm},
  newuserpassDlg in 'newuserpassDlg.pas' {newuserpassFrm},
  optionsDlg in 'optionsDlg.pas' {optionsFrm},
  Rejetto.Utils in 'Rejetto.Utils.pas',
  longinputDlg in 'longinputDlg.pas' {longinputFrm},
  folderKindDlg in 'folderKindDlg.pas' {folderKindFrm},
  shellExtDlg in 'shellExtDlg.pas' {shellExtFrm},
  diffDlg in 'diffDlg.pas' {diffFrm},
  Rejetto in 'Rejetto.pas',
  ipsEverDlg in 'ipsEverDlg.pas' {ipsEverFrm},
  Rejetto.Parser in 'Rejetto.Parser.pas',
  purgeDlg in 'purgeDlg.pas' {purgeFrm},
  listSelectDlg in 'listSelectDlg.pas' {listSelectFrm},
  filepropDlg in 'filepropDlg.pas' {filepropFrm},
  runscriptDlg in 'runscriptDlg.pas' {runScriptFrm},
  Rejetto.Script in 'Rejetto.Script.pas',
  HFS.Template in 'HFS.Template.pas',
  HFS.Consts in 'HFS.Consts.pas',
  HFS.Accounts in 'HFS.Accounts.pas',
  Rejetto.Utils.Text in 'Rejetto.Utils.Text.pas',
  Rejetto.Utils.Registry in 'Rejetto.Utils.Registry.pas',
  Rejetto.Utils.Conversion in 'Rejetto.Utils.Conversion.pas',
  Rejetto.Math in 'Rejetto.Math.pas',
  Rejetto.Consts in 'Rejetto.Consts.pas',
  Rejetto.Utils.URL in 'Rejetto.Utils.URL.pas';

{$R *.res}

procedure processSlaveParams(params: string);
var
  ss: TStringDynArray;
begin
  if mainfrm = NIL then
    exit;
  ss := split(#13, params);
  processParams_before(ss);
  mainfrm.processParams_after(ss);
end;

function isSingleInstance(): boolean;
var
  params: TStringDynArray;
  ini, tpl: string;
begin
  result := FALSE;
  // the -i parameter affects loadCfg()
  params := paramsAsArray();
  processParams_before(params, 'i');
  loadCfg(ini, tpl);
  Chop('only-1-instance=', ini);
  if ini = '' then
    exit;
  ini := ChopLine(ini);
  result := sameText(ini, 'yes');
end;

begin
  mono.onSlaveParams := processSlaveParams;
  if not holdingKey(VK_CONTROL) then
  begin
    if not mono.Init('HttpFileServer') then
    begin
      msgDlg('monoLib error: ' + mono.Error, MB_ICONERROR + MB_OK);
      halt(1);
    end;
    if not mono.Master and isSingleInstance() then
    begin
      mono.SendParams();
      exit;
    end;
  end;

{$IFDEF EX_DEBUG}
  initErrorHandler(format('HFS %s (%s)', [VERSION, VERSION_BUILD]));
{$ENDIF}
  Application.Initialize();
  Application.CreateForm(TmainFrm, mainfrm);
  Application.CreateForm(TnewuserpassFrm, newuserpassFrm);
  Application.CreateForm(ToptionsFrm, optionsFrm);
  Application.CreateForm(TdiffFrm, diffFrm);
  Application.CreateForm(TipsEverFrm, ipsEverFrm);
  Application.CreateForm(TrunScriptFrm, runScriptFrm);
  mainfrm.finalInit();
  Application.Run;
{$IFDEF EX_DEBUG}
  closeErrorHandler();
{$ENDIF}
end.
