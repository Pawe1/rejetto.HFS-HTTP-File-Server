{
Copyright (C) 2002-2012  Massimo Melina (www.rejetto.com)

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
    along with HFS; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}
unit optionsDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Grids, Vcl.ValEdit;

type
  ToptionsFrm = class(TForm)
    pageCtrl: TPageControl;
    bansPage: TTabSheet;
    accountsPage: TTabSheet;
    accountpropGrp: TGroupBox;
    accountenabledChk: TCheckBox;
    pwdBox: TLabeledEdit;
    Label1: TLabel;
    deleteaccountBtn: TButton;
    renaccountBtn: TButton;
    mimePage: TTabSheet;
    mimeBox: TValueListEditor;
    trayPage: TTabSheet;
    Label2: TLabel;
    traymsgBox: TMemo;
    Panel1: TPanel;
    Label3: TLabel;
    accountAccessBox: TTreeView;
    Panel2: TPanel;
    okBtn: TButton;
    applyBtn: TButton;
    cancelBtn: TButton;
    bansBox: TValueListEditor;
    addBtn: TButton;
    deleteBtn: TButton;
    Panel3: TPanel;
    noreplybanChk: TCheckBox;
    Button1: TButton;
    a2nPage: TTabSheet;
    Panel4: TPanel;
    Label4: TLabel;
    a2nBox: TValueListEditor;
    ignoreLimitsChk: TCheckBox;
    Panel5: TPanel;
    addMimeBtn: TButton;
    deleteMimeBtn: TButton;
    deleteA2Nbtn: TButton;
    addA2Nbtn: TButton;
    iconsPage: TTabSheet;
    iconMasksBox: TMemo;
    iconsBox: TComboBox;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    redirBox: TLabeledEdit;
    inBrowserIfMIMEchk: TCheckBox;
    traypreviewBox: TMemo;
    Label10: TLabel;
    accountLinkBox: TLabeledEdit;
    groupChk: TCheckBox;
    groupsBtn: TButton;
    addaccountBtn: TButton;
    upBtn: TButton;
    downBtn: TButton;
    sortBtn: TButton;
    notesBox: TMemo;
    Label8: TLabel;
    sortBanBtn: TButton;
    notesWrapChk: TCheckBox;
    accountsBox: TListView;
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure addaccountBtnClick(Sender: TObject);
    procedure deleteaccountBtnClick(Sender: TObject);
    procedure accountsBoxEdited(Sender: TObject; Item: TListItem; var S: String);
    procedure renaccountBtnClick(Sender: TObject);
    procedure accountAccessBoxDblClick(Sender: TObject);
    procedure accountAccessBoxContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure cancelBtnClick(Sender: TObject);
    procedure okBtnClick(Sender: TObject);
    procedure applyBtnClick(Sender: TObject);
    procedure addBtnClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure deleteBtnClick(Sender: TObject);
    procedure pwdBoxEnter(Sender: TObject);
    procedure pwdBoxExit(Sender: TObject);
    procedure addMimeBtnClick(Sender: TObject);
    procedure deleteMimeBtnClick(Sender: TObject);
    procedure addA2NbtnClick(Sender: TObject);
    procedure deleteA2NbtnClick(Sender: TObject);
    procedure iconsBoxDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure iconsBoxDropDown(Sender: TObject);
    procedure iconsBoxChange(Sender: TObject);
    procedure iconMasksBoxChange(Sender: TObject);
    procedure traymsgBoxChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure accountLinkBoxExit(Sender: TObject);
    procedure groupChkClick(Sender: TObject);
    procedure groupsBtnClick(Sender: TObject);
    procedure accountenabledChkClick(Sender: TObject);
    procedure upBtnClick(Sender: TObject);
    procedure sortBtnClick(Sender: TObject);
    procedure ListView1DragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure upBtnMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure sortBanBtnClick(Sender: TObject);
    procedure notesWrapChkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure accountsBoxData(Sender: TObject; Item: TListItem);
    procedure accountsBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure accountsBoxClick(Sender: TObject);
    procedure accountsBoxDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure accountsBoxDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure accountsBoxChange(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure updateAccessBox();
    procedure accountsBoxDblClick(Sender: TObject);
    procedure redirBoxChange(Sender: TObject);
    procedure accountsBoxKeyPress(Sender: TObject; var Key: Char);
    procedure accountsBoxEditing(Sender: TObject; Item: TListItem;
      var AllowEdit: Boolean);
  public
    procedure checkRedir();
		procedure loadAccountProperties();
		function saveAccountProperties():boolean;
		procedure deleteAccount(idx:integer=-1);
    procedure loadValues();
    function  saveValues():boolean; // it may fail on incorrect input
    function  checkValues():string; // returns an error message
    procedure updateIconMap();
    procedure updateIconsBox();
    procedure selectAccount(i:integer; saveBefore:boolean=TRUE);
  end;

var
  optionsFrm: ToptionsFrm;

implementation

{$R *.dfm}

uses
  System.Types, System.Math,
  main, CheckLst,
  Rejetto.Utils, Rejetto.HTTPServer, strUtils, Rejetto, listSelectDlg,
  HFS.Consts,
  HFS.Accounts;

var
  lastAccountSelected: integer = -1; // stores the previous selection index
  tempAccounts: TAccounts; // the GUI part can't store the temp data
  tempIcons: array of integer;
  renamingAccount: boolean;

procedure ToptionsFrm.selectAccount(i: Integer; saveBefore: Boolean = TRUE);
begin
  if saveBefore then
    saveAccountProperties();
  accountsBox.itemIndex := i;
  accountsBox.ItemFocused := accountsBox.Selected;
  loadAccountProperties();
end;

procedure ToptionsFrm.loadValues();
var
  i: Integer;
begin
  // bans
  noreplybanChk.checked := noReplyBan;
  bansBox.Strings.Clear();
  for i := 0 to length(banList) - 1 do
    bansBox.Strings.Add(banList[i].ip + '=' + banList[i].comment);
  // mime types
  inBrowserIfMIMEchk.checked := inBrowserIfMIME;
  mimeBox.Strings.Clear();
  for i := 0 to length(mimeTypes) div 2 - 1 do
    mimeBox.Strings.Add(mimeTypes[i * 2] + '=' + mimeTypes[i * 2 + 1]);
  for i := 0 to length(DEFAULT_MIME_TYPES) div 2 - 1 do
    if not stringExists(DEFAULT_MIME_TYPES[i * 2], mimeTypes) then
      mimeBox.Strings.Add(DEFAULT_MIME_TYPES[i * 2] + '=' + DEFAULT_MIME_TYPES
        [i * 2 + 1]);
  // address2name
  a2nBox.Strings.Clear();
  for i := 0 to length(address2name) div 2 - 1 do
    a2nBox.Strings.Add(address2name[i * 2] + '=' + address2name[i * 2 + 1]);
  // tray message
  traymsgBox.Text := xtpl(trayMsg, [#13, CRLF]);
  // accounts
  tempAccounts := accounts;
  setLength(tempAccounts, length(tempAccounts)); // unlink from the source
  accountsBox.items.count := length(accounts);
  lastAccountSelected := -1;
  loadAccountProperties();
  // remember original name for tracking possible later renaming
  for i := 0 to length(accounts) - 1 do
    with accounts[i] do
      wasUser := user;
  // icons
  updateIconsBox();
  i := length(iconMasks);
  setLength(tempIcons, i + 1);
  iconMasksBox.Text := '';
  for i := 0 to i - 1 do
  begin
    iconMasksBox.lines.Add(iconMasks[i].str);
    tempIcons[i] := iconMasks[i].int;
  end;
  iconMasksBox.SelStart := 0;
end;

procedure ToptionsFrm.notesWrapChkClick(Sender: TObject);
begin
  notesBox.WordWrap := notesWrapChk.checked;
  if notesBox.WordWrap then
    notesBox.ScrollBars := ssVertical
  else
    notesBox.ScrollBars := ssBoth
end;

function ToptionsFrm.checkValues(): string;
var
  i: Integer;
  S: string;
begin
  for i := bansBox.Strings.count downto 1 do
  begin
    bansBox.cells[0, i] := trim(bansBox.cells[0, i]);
    S := bansBox.cells[0, i];
    if S = '' then
      continue;
    if bansBox.Strings.indexOfName(S) + 1 < i then
    begin
      result := format('Bans: "%s" is duplicated', [S]);
      exit;
    end;
    if not checkAddressSyntax(S) then
    begin
      result := format('Bans: syntax error for "%s"', [S]);
      exit;
    end;
  end;
  for i := a2nBox.Strings.count downto 1 do
  begin
    S := trim(a2nBox.cells[1, i]);
    if trim(S + a2nBox.cells[0, i]) = '' then
      a2nBox.DeleteRow(i)
    else if (S > '') and not checkAddressSyntax(S) then
    begin
      result := format('Address2name: syntax error for "%s"', [S]);
      exit;
    end;
  end;
  result := '';
end;

function ToptionsFrm.saveValues(): Boolean;
var
  i, n: Integer;
  S: string;
begin
  result := FALSE;
  S := checkValues();
  if S > '' then
  begin
    msgDlg(S, MB_ICONERROR);
    exit;
  end;
  if not saveAccountProperties() then
    exit;
  // bans
  noReplyBan := noreplybanChk.checked;
  i := bansBox.Strings.count;
  if bansBox.cells[0, i] = '' then
    dec(i);
  setLength(banList, i);
  n := 0;
  for i := 0 to length(banList) - 1 do
  begin
    banList[n].ip := trim(bansBox.cells[0, i + 1]); // mod by mars
    if banList[n].ip = '' then
      continue;
    banList[n].comment := bansBox.cells[1, i + 1];
    inc(n);
  end;
  setLength(banList, n);
  kickBannedOnes();
  // mime types
  inBrowserIfMIME := inBrowserIfMIMEchk.checked;
  mimeTypes := NIL;
  for i := 1 to mimeBox.rowCount - 1 do
    addArray(mimeTypes, [mimeBox.cells[0, i], mimeBox.cells[1, i]]);

  // address2name
  address2name := NIL;
  for i := 1 to a2nBox.rowCount - 1 do
  begin
    S := trim(a2nBox.cells[1, i]);
    if S > '' then
      addArray(address2name, [a2nBox.cells[0, i], S]);
  end;
  // tray message
  trayMsg := xtpl(traymsgBox.Text, [#10, '']);
  // accounts
  accounts := tempAccounts;
  purgeVFSaccounts();
  mainfrm.filesBox.repaint();
  // icons
  setLength(iconMasks, 0); // mod by mars
  n := 0;
  for i := 0 to iconMasksBox.lines.count - 1 do
  begin
    S := iconMasksBox.lines[i];
    if trim(S) = '' then
      continue;
    inc(n);
    setLength(iconMasks, n);
    iconMasks[n - 1].str := S;
    iconMasks[n - 1].int := tempIcons[i];
  end;
  result := TRUE;
end;

function ipListComp(list: TStringList; index1, index2: integer):integer;

  function extract(S: string; var o: Integer): string;
  var
    i: Integer;
  begin
    i := posEx('.', S, o);
    if i = 0 then
      i := length(S) + 1;
    result := substr(S, o, i - 1);
    o := i + 1;
  end; // extract

  function compare(a, b: string): Integer;
  begin
    try
      result := compare_(strToInt(a), strToInt(b));
    except
      result := compare_(length(a), length(b));
      if result = 0 then
        result := ansiCompareStr(a, b);
    end;
  end; // compare

var
  o1, o2: Integer;
  s1, s2: string;
begin
  s1 := getTill('=', list[index1]);
  s2 := getTill('=', list[index2]);
  o1 := 1;
  o2 := 1;
  repeat
    result := compare(extract(s1, o1), extract(s2, o2));
  until (result <> 0) or (o1 > length(s1)) and (o2 > length(s2));
end;

procedure ToptionsFrm.sortBanBtnClick(Sender: TObject);
begin
  (bansBox.Strings as TStringList).customSort(ipListComp);
end;

procedure ToptionsFrm.sortBtnClick(Sender: TObject);

  function sortIt(reverse: Boolean = FALSE): Boolean;
  var
    S, i, j, l: Integer;
  begin
    result := FALSE;
    S := accountsBox.itemIndex;
    l := length(tempAccounts);
    for i := 0 to l - 2 do
      for j := i + 1 to l - 1 do
        if reverse XOR (compareText(tempAccounts[i].user,
          tempAccounts[j].user) > 0) then
        begin
          swapMem(tempAccounts[i], tempAccounts[j], sizeof(tempAccounts[0]));
          if i = S then
            S := j
          else if j = S then
            S := i;
          result := TRUE;
        end;
    accountsBox.itemIndex := S;
  end; // sortIt

begin
  lastAccountSelected := -1;
  if not sortIt(FALSE) then
    sortIt(TRUE);
  accountsBox.invalidate();
end;

procedure ToptionsFrm.traymsgBoxChange(Sender: TObject);
begin
  traypreviewBox.Text := mainfrm.getTrayTipMsg(traymsgBox.Text)
end;

procedure ToptionsFrm.FormShow(Sender: TObject);
var
  i: Integer;
  S: string;
begin
  // if we do this, any hint window will bring focus to the main form
  // setwindowlong(handle, GWL_HWNDPARENT, 0); // get a taskbar button
  loadValues();
  if pageCtrl.activePage <> a2nPage then
    exit;
  S := mainfrm.ipPointedInLog();
  if S = '' then
    exit;
  // select row or insert new one
  i := length(address2name) - 1;
  while (i > 0) and not addressmatch(address2name[i], S) do
    dec(i, 2);
  if i <= 0 then
    a2nBox.row := a2nBox.insertRow('', S, TRUE)
  else
    try
      a2nBox.row := i
    except
    end; // this should not happen, but in case (it was reported once) just skip selecting

  a2nBox.SetFocus();
  a2nBox.EditorMode := TRUE;
end;

procedure ToptionsFrm.groupChkClick(Sender: TObject);
begin
  pwdBox.visible := not groupChk.checked;
  accountsBox.invalidate();
end;

procedure ToptionsFrm.FormActivate(Sender: TObject);
begin
  traymsgBoxChange(NIL)
end;

procedure ToptionsFrm.FormCreate(Sender: TObject);
begin
  notesWrapChk.checked := TRUE;
end;

procedure ToptionsFrm.FormResize(Sender: TObject);
begin
  bansBox.ColWidths[1] := bansBox.ClientWidth - bansBox.ColWidths[0] - 2
end;

procedure setEnabledRecur(c: Tcontrol; v: Boolean);
var
  i: Integer;
begin
  c.enabled := v;
  if c is TTreeView then
    (c as TTreeView).items.Clear();
  if c is TLabeledEdit then
    (c as TLabeledEdit).Text := '';
  if c is TMemo then
    (c as TMemo).Text := '';
  if c is TCheckBox then
    (c as TCheckBox).checked := FALSE;

  if c is TWinControl then
    with c as TWinControl do
      for i := 0 to controlCount - 1 do
        setEnabledRecur(Controls[i], v);
end;

procedure ToptionsFrm.updateAccessBox();
var
  n: Ttreenode;
  f: Tfile;
  props: TstringDynArray;
  act: TfileAction;
  S: string;
  a, other: PAccount;
begin
  accountAccessBox.items.Clear();
  if lastAccountSelected < 0 then
    exit;
  a := @tempAccounts[lastAccountSelected];
  n := rootNode;
  while n <> NIL do
  begin
    f := Tfile(n.data);
    n := n.getNext();
    if f = NIL then
      continue;

    props := NIL;
    for act := low(TfileAction) to high(TfileAction) do
    begin
      S := FILEACTION2STR[act];
      // any_account will suffice, otherwise our username (or a linked one) must be there explicitly, otherwise the resource is not protected or we have no access and thus must not be listed
      if not stringExists(USER_ANY_ACCOUNT, f.accounts[act]) then
      begin
        other := findEnabledLinkedAccount(a, f.accounts[act]);
        if other = NIL then
          continue;
        if other <> a then
          S := S + ' via ' + other.user;
      end;
      addString(S, props);
    end;
    if props = NIL then
      continue;

    with accountAccessBox.items.addObject(NIL, f.name + ' [' + join(', ', props)
      + ']', f.node) do
    begin
      imageIndex := f.node.imageIndex;
      selectedIndex := imageIndex;
    end;
  end;
end;

procedure ToptionsFrm.checkRedir();
begin // mod by mars
  redirBox.color := blend(clWindow, clRed,
    ifThen((redirBox.Text > '') and not fileExistsByURL(redirBox.Text),
    0.5, 0));
end;

procedure ToptionsFrm.loadAccountProperties();
var
  a: PAccount;
  b, bakWrap: Boolean;
  i: Integer;
begin
  lastAccountSelected := accountsBox.itemIndex;
  b := lastAccountSelected >= 0;
  bakWrap := notesWrapChk.checked;
  setEnabledRecur(accountpropGrp, b);
  notesWrapChk.checked := bakWrap;
  renaccountBtn.enabled := b;
  deleteaccountBtn.enabled := b;
  upBtn.enabled := b;
  downBtn.enabled := b;

  if not accountpropGrp.enabled then
    exit;
  a := @tempAccounts[lastAccountSelected];
  accountenabledChk.checked := a.enabled;
  pwdBox.Text := a.pwd;
  groupChk.checked := a.group;
  accountLinkBox.Text := join(';', a.link);
  ignoreLimitsChk.checked := a.noLimits;
  redirBox.Text := a.redir;
  notesBox.Text := a.notes;

  groupsBtn.enabled := FALSE;;
  for i := 0 to length(tempAccounts) - 1 do
    if tempAccounts[i].group and (i <> accountsBox.itemIndex) then
      groupsBtn.enabled := TRUE;

  updateAccessBox();
  accountsBox.invalidate();
end;

function ToptionsFrm.saveAccountProperties(): Boolean;
const
  MSG_CHARS = 'The characters below are not allowed' + #13'/\:?*"<>|;&&@';
  MSG_PWD = 'Invalid password.'#13 + MSG_CHARS;
var
  a: PAccount;
begin
  result := TRUE;
  if lastAccountSelected < 0 then
    exit;
  result := FALSE;
  if not validUsername(pwdBox.Text, TRUE) then
  begin
    msgDlg(MSG_PWD, MB_ICONERROR);
    exit;
  end;

  a := @tempAccounts[lastAccountSelected];
  a.enabled := accountenabledChk.checked;
  a.pwd := pwdBox.Text;
  a.noLimits := ignoreLimitsChk.checked;
  a.redir := redirBox.Text;
  a.notes := notesBox.Text;
  a.link := split(';', trim(accountLinkBox.Text));
  a.group := groupChk.checked;
  uniqueStrings(a.link);
  result := TRUE;
  accountsBox.invalidate();
end;

function findUser(user: string): Integer;
begin
  result := length(tempAccounts) - 1;
  while (result >= 0) and not sameText(tempAccounts[result].user, user) do
    dec(result);
end; // findUser

function userExists(user: string): Boolean; overload;
begin
  result := findUser(user) >= 0
end;

function userExists(user: string; excpt: Integer): Boolean; overload;
var
  i: Integer;
begin
  i := findUser(user);
  result := (i >= 0) and (i <> excpt);
end;

procedure ToptionsFrm.addaccountBtnClick(Sender: TObject);
var
  i: Integer;
  a: TAccount;
begin
  a.user := getUniqueName('new user', userExists);
  a.pwd := '';
  a.enabled := TRUE;
  a.noLimits := FALSE;
  a.redir := '';

  i := length(tempAccounts);
  setLength(tempAccounts, i + 1);
  tempAccounts[i] := a;
  accountsBox.items.Add();
  selectAccount(i);

  renaccountBtnClick(Sender);
end;

procedure ToptionsFrm.deleteAccount(idx: Integer = -1);
var
  i: Integer;
begin
  if idx < 0 then
  begin
    idx := accountsBox.itemIndex;
    if idx < 0 then
      exit;
    if msgDlg('Delete?', MB_ICONQUESTION + MB_YESNO) = IDNO then
      exit;
  end;
  // shift
  for i := idx + 1 to length(tempAccounts) - 1 do
    tempAccounts[i - 1] := tempAccounts[i];
  // shorten
  with accountsBox.items do
    count := count - 1; // dunno why, but invoking delete* methods doesn't work
  setLength(tempAccounts, length(tempAccounts) - 1);
  selectAccount(min(idx, length(tempAccounts) - 1), FALSE);
end;

procedure ToptionsFrm.deleteaccountBtnClick(Sender: TObject);
begin
  deleteAccount()
end;

procedure swapItems(i, j: Integer);
var
  S: Integer;
begin
  S := length(tempAccounts) - 1;
  if not inRange(i, 0, S) or not inRange(j, 0, S) then
    exit;
  S := optionsFrm.accountsBox.itemIndex;
  lastAccountSelected := -1; // avoid data saving from fields while moving
  swapMem(tempAccounts[i], tempAccounts[j], sizeof(tempAccounts[i]));
  if i = S then
    S := j
  else if j = S then
    S := i;
  with optionsFrm.accountsBox do
  begin
    itemIndex := S;
    Selected.focused := TRUE;
    invalidate();
  end;
end; // swapItems

procedure ToptionsFrm.accountsBoxChange(Sender: TObject; Item: TListItem;
  Change: TItemChange);
begin
  if (Change = ctState) and assigned(Item) and Item.Selected then
    selectAccount(Item.Index);
end;

procedure ToptionsFrm.accountsBoxClick(Sender: TObject);
begin
  selectAccount(accountsBox.itemIndex);
end;

procedure ToptionsFrm.accountsBoxData(Sender: TObject; Item: TListItem);
var
  a: PAccount;
begin
  if (Item = NIL) or not inRange(Item.Index, 0, length(tempAccounts) - 1) then
    exit;
  a := @tempAccounts[Item.Index];
  Item.caption := a.user;
  Item.imageIndex := if_(Item.Index = lastAccountSelected,
    accountIcon(accountenabledChk.checked, groupChk.checked), accountIcon(a));
end;

procedure ToptionsFrm.accountsBoxDblClick(Sender: TObject);
begin
  renaccountBtnClick(renaccountBtn)
end;

procedure ToptionsFrm.accountsBoxDragDrop(Sender, Source: TObject;
  X, Y: Integer);
begin
  swapItems(accountsBox.getItemAt(X, Y).Index, accountsBox.itemIndex);
end;

procedure ToptionsFrm.accountsBoxDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Sender = Source) and assigned(accountsBox.getItemAt(X, Y));
end;

procedure ToptionsFrm.accountsBoxEdited(Sender: TObject; Item: TListItem;
  var S: String);
var
  old, err: string;
  i, idx: Integer;
begin
  renamingAccount := FALSE;
  try
    idx := Item.Index
    // workaround to wine's bug http://www.rejetto.com/forum/index.php/topic,9563.msg1053890.html#msg1053890
  except
    idx := lastAccountSelected
  end;
  old := tempAccounts[idx].user;
  if not validUsername(S) then
    err := 'Invalid username'
  else if userExists(S, accountsBox.itemIndex) then
    err := 'Username already used'
  else
    err := '';

  if err > '' then
  begin
    msgDlg(err, MB_ICONERROR);
    S := old;
    exit;
  end;
  // update linkings
  for i := 0 to length(tempAccounts) - 1 do
    replaceString(tempAccounts[i].link, old, S);
  tempAccounts[idx].user := S;
end;

procedure ToptionsFrm.accountsBoxEditing(Sender: TObject; Item: TListItem;
  var AllowEdit: Boolean);
begin
  renamingAccount := TRUE;
end;

procedure ToptionsFrm.accountsBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Shift = [] then
    case Key of
      VK_F2:
        renaccountBtn.click();
      VK_INSERT:
        addaccountBtn.click(); // mod by mars
      VK_DELETE:
        deleteAccount();
    end;
  { mod by mars }
  if Shift = [ssAlt] then
    case Key of
      VK_UP:
        upBtn.click();
      VK_DOWN:
        downBtn.click();
    end;
  { /mod }
end;

procedure ToptionsFrm.accountsBoxKeyPress(Sender: TObject; var Key: Char);
var
  S, i, ir, n: Integer;
begin
  if renamingAccount then
    exit;
  Key := upcase(Key);
  if Key in ['0' .. '9', 'A' .. 'Z'] then
  begin
    S := accountsBox.itemIndex;
    n := length(tempAccounts);
    for i := 1 to n - 1 do
    begin
      ir := (S + i) mod n;
      if Key = upcase(tempAccounts[ir].user[1]) then
      begin
        selectAccount(ir);
        exit;
      end;
    end;
  end;
end;

procedure ToptionsFrm.redirBoxChange(Sender: TObject);
begin
  checkRedir()
end;

procedure ToptionsFrm.renaccountBtnClick(Sender: TObject);
begin
  if accountsBox.Selected = NIL then
    exit;
  accountsBox.Selected.editCaption();
end;

procedure ToptionsFrm.accountLinkBoxExit(Sender: TObject);
const
  MSG_MISSING_USERS = 'Cannot find these linked usernames: %s' +
    #13'This is abnormal, but you may add them later.';
var
  users, missing: TstringDynArray;
  i: Integer;
begin
  users := split(';', trim(accountLinkBox.Text));
  // check for non-existent linked account
  missing := NIL;
  for i := 0 to length(users) - 1 do
    if not userExists(users[i]) then
      addString(users[i], missing);
  if assigned(missing) then
    msgDlg(format(MSG_MISSING_USERS, [join(', ', missing)]), MB_ICONWARNING);
  // permissions may have been changed
  updateAccessBox();
end;

procedure ToptionsFrm.accountAccessBoxDblClick(Sender: TObject);
begin
  with Sender as TTreeView do
  begin
    if Selected = NIL then
      exit;
    mainfrm.filesBox.Selected := Selected.data;
    mainfrm.SetFocus();
  end;
end;

procedure ToptionsFrm.accountenabledChkClick(Sender: TObject);
begin
  accountsBox.invalidate()
end;

procedure ToptionsFrm.accountAccessBoxContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: Boolean);
begin
  with Sender as TTreeView do
    if Selected = NIL then
      Handled := TRUE
    else
      mainfrm.filesBox.Selected := Selected.data;
end;

procedure ToptionsFrm.cancelBtnClick(Sender: TObject);
begin
  close()
end;

procedure ToptionsFrm.applyBtnClick(Sender: TObject);
begin
  saveValues()
end;

procedure ToptionsFrm.okBtnClick(Sender: TObject);
begin
  if saveValues() then
    close()
end;

procedure ToptionsFrm.Button1Click(Sender: TObject);
begin
  msgDlg(getRes('invertBan'))
end;

procedure ToptionsFrm.groupsBtnClick(Sender: TObject);
var
  i: Integer;
  there: TstringDynArray;
  groups: TStringList;
  S: string;
begin
  there := split(';', accountLinkBox.Text);
  groups := TStringList.create;
  try
    for i := 0 to length(tempAccounts) - 1 do
      if tempAccounts[i].group and (i <> accountsBox.itemIndex) then
      begin
        S := tempAccounts[i].user;
        groups.addObject(S, if_(stringExists(S, there), PTR1, NIL));
      end;
    if not listSelect('Select groups', groups) then
      exit;
    S := '';
    for i := 0 to groups.count - 1 do
      if groups.Objects[i] <> NIL then
        S := S + groups[i] + ';';
    accountLinkBox.Text := getTill(-1, S);
  finally
    groups.free
  end;
end;

procedure ToptionsFrm.pwdBoxEnter(Sender: TObject);
begin
  if pwdBox.Text > '' then
    pwdBox.passwordChar := #0
end;

procedure ToptionsFrm.pwdBoxExit(Sender: TObject);
begin
  pwdBox.passwordChar := '*'
end;

procedure ToptionsFrm.addBtnClick(Sender: TObject);
begin
  bansBox.insertRow('', '', TRUE)
end;

procedure ToptionsFrm.deleteBtnClick(Sender: TObject);
begin
  if bansBox.Strings.count > 0 then
    bansBox.Strings.Delete(bansBox.row - 1)
end;

procedure ToptionsFrm.addMimeBtnClick(Sender: TObject);
begin
  mimeBox.insertRow('', '', TRUE)
end;

procedure ToptionsFrm.deleteMimeBtnClick(Sender: TObject);
begin
  if mimeBox.Strings.count > 0 then
    mimeBox.Strings.Delete(mimeBox.row - 1)
end;

procedure ToptionsFrm.addA2NbtnClick(Sender: TObject);
begin
  a2nBox.insertRow('', '', TRUE);
  a2nBox.SetFocus();
end;

procedure ToptionsFrm.deleteA2NbtnClick(Sender: TObject);
begin
  if a2nBox.Strings.count > 0 then
    a2nBox.Strings.Delete(a2nBox.row - 1)
end;

procedure ToptionsFrm.iconsBoxDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  cnv: TCanvas;
  bmp: Tbitmap;
begin
  cnv := iconsBox.Canvas;
  bmp := Tbitmap.create;
  try
    mainfrm.images.GetBitmap(index, bmp);
    cnv.FillRect(Rect);
    cnv.Draw(Rect.Left, Rect.Top, bmp);
    cnv.TextOut(Rect.Left + mainfrm.images.Width + 2, Rect.Top,
      idx_label(index));
  finally
    bmp.free
  end;
end;

procedure ToptionsFrm.updateIconsBox();
// alloc enough slots. the text is not used, labels are built by the paint event
begin
  iconsBox.items.Text := dupeString(CRLF, mainfrm.images.count)
end;

procedure ToptionsFrm.iconsBoxDropDown(Sender: TObject);
begin
  updateIconsBox()
end;

procedure ToptionsFrm.ListView1DragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := Source = Sender;
end;

procedure ToptionsFrm.upBtnClick(Sender: TObject);
var
  i, dir: Integer;
begin
  dir := if_(Sender = upBtn, -1, +1);
  i := accountsBox.itemIndex;
  if not inRange(i + dir, 0, length(tempAccounts) - 1) then
    exit;
  swapItems(i, i + dir);
end;

procedure ToptionsFrm.upBtnMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  accountsBox.SetFocus()
end;

procedure ToptionsFrm.updateIconMap();
begin
  if not iconsBox.DroppedDown then
    iconsBox.itemIndex := tempIcons[iconMasksBox.CaretPos.Y];
end;

procedure ToptionsFrm.iconsBoxChange(Sender: TObject);
begin
  tempIcons[iconMasksBox.CaretPos.Y] := iconsBox.itemIndex
end;

procedure ToptionsFrm.iconMasksBoxChange(Sender: TObject);
begin
  setLength(tempIcons, iconMasksBox.lines.count + 1)
end;

end.
