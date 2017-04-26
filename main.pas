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
    along with HFS; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}
{$A+,B-,C+,E-,F-,G+,H+,I-,J-,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,X+,Y+,Z1}
{$INCLUDE defs.inc }

unit main;

interface

uses
  // delphi libs
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.Menus, Vcl.ComCtrls, Vcl.ExtCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Buttons, Vcl.StdCtrls, Vcl.ToolWin, Vcl.AppEvnts,
  System.Math, System.Win.Registry,  Winapi.ShellAPI, System.StrUtils,
  System.Types, Winapi.WinSock, Vcl.Clipbrd, Winapi.ShlObj, Winapi.ActiveX,
  Vcl.FileCtrl, System.DateUtils, System.IniFiles,

  // 3rd part libs. ensure you have all of these, the same version reported in dev-notes.txt
  OverbyteIcsWSocket, OverbyteIcsHttpProt, OverbyteicsMD5,
  zlibex,
  regexpr,

  // rejetto libs
  Rejetto.HTTPServer, traylib, Rejetto.Mono, progFrmLib, Rejetto,
  HFS.Template, HFS.Consts;

type
  Pboolean = ^boolean;

  TfileAttribute = (
    FA_FOLDER,       // folder kind
    FA_VIRTUAL,      // does not exist on disc
    FA_ROOT,         // only the root item has this attribute
    FA_BROWSABLE,    // permit listing of this folder (not recursive, only dir)
    FA_HIDDEN,       // hidden iterms won't be shown to browsers (not recursive)
    { no more used attributes have to stay for backward compatibility with
    { VFS files }
    FA_NO_MORE_USED1,
  	FA_NO_MORE_USED2,
    FA_TEMP,            // this is a temporary item and is not part of the VFS
    FA_HIDDENTREE,      // recursive hidden
    FA_LINK,            // redirection
    FA_UNIT,            // logical unit (drive)
    FA_VIS_ONLY_ANON,   // visible only to anonymous users [no more used]
    FA_DL_FORBIDDEN,    // forbid download (not recursive)
    FA_HIDE_EMPTY_FOLDERS,  // (recursive)
    FA_DONT_COUNT_AS_DL,    // (not recursive)
    FA_SOLVED_LNK,
    FA_HIDE_EXT,       // (recursive)
    FA_DONT_LOG,       // (recursive)
    FA_ARCHIVABLE      // (recursive)
  );
  TfileAttributes = set of TfileAttribute;

  Tfile = class;
  TconnData = class;

  TfileCallbackReturn = set of (FCB_NO_DEEPER, FCB_DELETE, FCB_RECALL_AFTER_CHILDREN); // use FCB_* flags

  // returning FALSE stops recursion
  TfileCallback = function(f: Tfile; childrenDone: boolean; par, par2: integer)
    : TfileCallbackReturn;

  TfileAction = (FA_ACCESS, FA_DELETE, FA_UPLOAD);

  Tfile = class (Tobject)
  private
    locked: boolean;
    FDLcount: integer;
    function getParent(): Tfile;
    function getDLcount(): integer;
    procedure setDLcount(i: integer);
    function getDLcountRecursive(): integer;
  public
    name, comment, user, pwd, lnk: string;
    resource: string;  // link to physical file/folder; URL for links
    flags: TfileAttributes;
    node: Ttreenode;
    size: int64; // -1 is NULL
    atime,            // when was this file added to the VFS ?
    mtime: Tdatetime; // modified time, read from disk
    icon: integer;
    accounts: array [TfileAction] of TStringDynArray;
    filesFilter, foldersFilter, realm, diffTpl, defaultFileMask,
      dontCountAsDownloadMask, uploadFilterMask: string;
    constructor create(fullpath: string);
    constructor createTemp(fullpath: string);
    constructor createVirtualFolder(name: string);
    constructor createLink(name: string);
    property parent: Tfile read getParent;
    property DLcount: integer read getDLcount write setDLcount;
    function toggle(att: TfileAttribute): boolean;
    function isFolder(): boolean; inline;
    function isFile(): boolean; inline;
    function isFileOrFolder(): boolean; inline;
    function isRealFolder(): boolean; inline;
    function isVirtualFolder(): boolean; inline;
    function isEmptyFolder(cd: TconnData = NIL): boolean;
    function isRoot(): boolean; inline;
    function isLink(): boolean; inline;
    function isTemp(): boolean; inline;
    function isNew(): boolean;
    function isDLforbidden(): boolean;
    function url(fullEncode: boolean = FALSE): string;
    function relativeURL(fullEncode: boolean = FALSE): string;
    function pathTill(root: Tfile = NIL; delim: char = '\'): string;
    function parentURL(): string;
    function fullURL(userpwd: string = ''; ip: string = ''): string;
    procedure setupImage(newIcon: integer); overload;
    procedure setupImage(); overload;
    function getAccountsFor(action: TfileAction;
      specialUsernames: boolean = FALSE; outInherited: Pboolean = NIL)
      : TStringDynArray;
    function accessFor(username, password: string): boolean; overload;
    function accessFor(cd: TconnData): boolean; overload;
    function hasRecursive(attributes: TfileAttributes;
      orInsteadOfAnd: boolean = FALSE; outInherited: Pboolean = NIL)
      : boolean; overload;
    function hasRecursive(attribute: TfileAttribute;
      outInherited: Pboolean = NIL): boolean; overload;
    function getSystemIcon(): integer;
    function getIconForTreeview(): integer;
    function getShownRealm(): string;
    function getFolder(): string;
    function getRecursiveFileMask(): string;
    function shouldCountAsDownload(): boolean;
    function getDefaultFile(): Tfile;
    procedure recursiveApply(callback: TfileCallback; par: integer = 0;
      par2: integer = 0);
    procedure getFiltersRecursively(var files, folders: string);
    function diskfree(): int64;
    function same(f: Tfile): boolean;
    procedure setName(name: string);
    procedure setResource(res: string);
    function getDynamicComment(skipParent: boolean = FALSE): string;
    procedure setDynamicComment(cmt: string);
    function getRecursiveDiffTplAsStr(outInherited: Pboolean = NIL;
      outFromDisk: Pboolean = NIL): string;
    // locking prevents modification of all its ancestors and descendants
    procedure lock();
    procedure unlock();
    function isLocked(): boolean;
  end; // Tfile

  Paccount = ^Taccount;
	Taccount = record // user/pass profile
    user, pwd, redir, notes: string;
    wasUser: string; // used in user renaming panel
    enabled, noLimits, group: boolean;
    link: TStringDynArray;
  end;
  Taccounts = array of Taccount;

  TfilterMethod = function(self:Tobject):boolean;

  Thelp = (HLP_NONE, HLP_TPL);

  TdownloadingWhat = ( DW_UNK, DW_FILE, DW_FOLDERPAGE, DW_ICON, DW_ERROR, DW_ARCHIVE );

  TpreReply =  (PR_NONE, PR_BAN, PR_OVERLOAD);

  TuploadResult = record
    fn, reason: string;
    speed: integer;
    size: int64;
  end;

  TconnData = class  // data associated to a client connection
  strict private
    type
      TETA = record
        idx: integer; // estimation time (seconds)
        data: array [0 .. ETA_FRAME - 1] of real; // accumulates speed data
        result: Tdatetime;
      end;

      TGroupingInfo = record
        bytes: integer;
        since: Tdatetime;
      end;
  private
    FlastFile: Tfile;
    procedure setLastFile(f: Tfile);
  public
    address: string;   // this is address shown in the log, and it is not necessarily the same as the socket address
    averageSpeed: real;   { calculated on disconnection as bytesSent/totalTime. it is calculated also while
                            sending and it is different from conn.speed because conn.speed is average speed
                            in the last second, while averageSpeed is calculated on ETA_FRAME seconds }
    time: Tdatetime;  // connection start time
    requestTime: Tdatetime; // last request start time
    tray: TmyTrayicon;
    tray_ico: Ticon;
    lastFN: string;
    countAsDownload: boolean; // cache the value for the Tfile method
    { cache User-Agent because often retrieved by connBox.
    { this value is filled after the http request is complete (HE_REQUESTED),
    { or before, during the request as we get a file (HE_POST_FILE). }
    agent: string;
    conn: ThttpConn;
    account: Paccount;
    usr, pwd: string;
    acceptedCredentials: boolean;
    limiter: TspeedLimiter;
    tpl: TTemplate;
    deleting: boolean;      // don't use, this item is about to be discarded
    nextDloadScreenUpdate: Tdatetime; // avoid too fast updating during download
    disconnectReason: string;
    error: string;         // error details
    eta: TETA;
    downloadingWhat: TdownloadingWhat;
    preReply: TpreReply;
    banReason: string;
    lastBytesSent, lastBytesGot: int64; // used for print to log only the recent amount of bytes
    lastActivityTime, fileXferStart: Tdatetime;
    uploadSrc, uploadDest: string;
    uploadFailed: string; // reason (empty on success)
    uploadResults: array of TuploadResult;
    disconnectAfterReply, logLaterInApache, dontLog, fullDLlogged: boolean;
    bytesGotGrouping, bytesSentGrouping: TGroupingInfo;
    sessionID: string;
    session,
    vars, // defined by {.set.}
    urlvars,  // as $_GET in php
    postVars  // as $_POST in php
      : THashedStringList;
    tplCounters: TstringToIntHash;
    workaroundForIEutf8: (toDetect, yes, no);
    { here we put just a pointer because the file type would triplicate
    { the size of this record, while it is NIL for most connections }
    f: ^file; // uploading file handle

    property lastFile: Tfile read FlastFile write setLastFile;
    constructor create(conn: ThttpConn);
    destructor Destroy; override;
    function sessionGet(k: string): string;
    procedure sessionSet(k, v: string);
    procedure disconnect(reason: string);
  end; // Tconndata

  Tautosave = record
    every, minimum: integer; // in seconds
    last: Tdatetime;
    menu: Tmenuitem;
  end;

  TtreeNodeDynArray = array of TtreeNode;

  TstringIntPairs = array of record
    str: string;
    int: integer;
  end;

  TmainFrm = class(TForm)
    filemenu: TPopupMenu;
    newfolder1: TMenuItem;
    images: TImageList;
    Remove1: TMenuItem;
    topToolbar: TToolBar;
    startBtn: TToolButton;
    ToolButton1: TToolButton;
    menuBtn: TToolButton;
    menu: TPopupMenu;
    About1: TMenuItem;
    connmenu: TPopupMenu;
    Kickconnection1: TMenuItem;
    KickIPaddress1: TMenuItem;
    Kickallconnections1: TMenuItem;
    Viewhttprequest1: TMenuItem;
    Saveoptions1: TMenuItem;
    toregistrycurrentuser1: TMenuItem;
    tofile1: TMenuItem;
    toregistryallusers1: TMenuItem;
    timer: TTimer;
    urlToolbar: TToolBar;
    IPaddress1: TMenuItem;
    AutocopyURLonadditionChk: TMenuItem;
    foldersbeforeChk: TMenuItem;
    Browseit1: TMenuItem;
    Openit1: TMenuItem;
    appEvents: TApplicationEvents;
    logmenu: TPopupMenu;
    DumprequestsChk: TMenuItem;
    CopyURL1: TMenuItem;
    Readonly1: TMenuItem;
    Clear1: TMenuItem;
    Copy1: TMenuItem;
    N3: TMenuItem;
    LogtimeChk: TMenuItem;
    LogdateChk: TMenuItem;
    Saveas1: TMenuItem;
    Save1: TMenuItem;
    N4: TMenuItem;
    connPnl: TPanel;
    MinimizetotrayChk: TMenuItem;
    Restore1: TMenuItem;
    Numberofcurrentconnections1: TMenuItem;
    Numberofloggeddownloads1: TMenuItem;
    Numberofloggedhits1: TMenuItem;
    Exit1: TMenuItem;
    Shellcontextmenu1: TMenuItem;
    Flashtaskbutton1: TMenuItem;
    onDownloadChk: TMenuItem;
    onconnectionChk: TMenuItem;
    never1: TMenuItem;
    N6: TMenuItem;
    startminimizedChk: TMenuItem;
    N7: TMenuItem;
    trayicons1: TMenuItem;
    trayfordownloadChk: TMenuItem;
    N8: TMenuItem;
    leavedisconnectedconnectionsChk: TMenuItem;
    Loadfilesystem1: TMenuItem;
    Savefilesystem1: TMenuItem;
    N1: TMenuItem;
    N12: TMenuItem;
    usesystemiconsChk: TMenuItem;
    N13: TMenuItem;
    Officialwebsite1: TMenuItem;
    numbers: TImageList;
    showmaintrayiconChk: TMenuItem;
    Speedlimit1: TMenuItem;
    N10: TMenuItem;
    Limits1: TMenuItem;
    Maxconnections1: TMenuItem;
    Maxconnectionsfromsingleaddress1: TMenuItem;
    Weblinks1: TMenuItem;
    Forum1: TMenuItem;
    FAQ1: TMenuItem;
    License1: TMenuItem;
    Paste1: TMenuItem;
    Addfiles1: TMenuItem;
    Addfolder1: TMenuItem;
    graphSplitter: TSplitter;
    Graphrefreshrate1: TMenuItem;
    Pausestreaming1: TMenuItem;
    Setuserpass1: TMenuItem;
    BanIPaddress1: TMenuItem;
    N2: TMenuItem;
    BannedIPaddresses1: TMenuItem;
    Loadrecentfiles1: TMenuItem;
    alwaysontopChk: TMenuItem;
    Checkforupdates1: TMenuItem;
    Rename1: TMenuItem;
    Otheroptions1: TMenuItem;
    Nodownloadtimeout1: TMenuItem;
    Autoclose1: TMenuItem;
    Showbandwidthgraph1: TMenuItem;
    Pause1: TMenuItem;
    reloadonstartupChk: TMenuItem;
    MIMEtypes1: TMenuItem;
    autocopyURLonstartChk: TMenuItem;
    Accounts1: TMenuItem;
    encodenonasciiChk: TMenuItem;
    encodeSpacesChk: TMenuItem;
    URLencoding1: TMenuItem;
    traymessage1: TMenuItem;
    DMbrowserTplChk: TMenuItem;
    Guide1: TMenuItem;
    autosaveVFSchk: TMenuItem;
    sendHFSidentifierChk: TMenuItem;
    persistentconnectionsChk: TMenuItem;
    Logfile1: TMenuItem;
    VirtualFileSystem1: TMenuItem;
    listfileswithhiddenattributeChk: TMenuItem;
    listfileswithsystemattributeChk: TMenuItem;
    hideProtectedItemsChk: TMenuItem;
    StartExit1: TMenuItem;
    Font1: TMenuItem;
    Newlink1: TMenuItem;
    SetURL1: TMenuItem;
    usecommentasrealmChk: TMenuItem;
    Resetuserpass1: TMenuItem;
    Switchtovirtual1: TMenuItem;
    LogiconsChk: TMenuItem;
    Loginrealm1: TMenuItem;
    Logwhat1: TMenuItem;
    N9: TMenuItem;
    N16: TMenuItem;
    logconnectionsChk: TMenuItem;
    logDisconnectionsChk: TMenuItem;
    logRequestsChk: TMenuItem;
    logRepliesChk: TMenuItem;
    logFulldownloadsChk: TMenuItem;
    logBytesreceivedChk: TMenuItem;
    logBytessentChk: TMenuItem;
    logServerstartChk: TMenuItem;
    logServerstopChk: TMenuItem;
    logBrowsingChk: TMenuItem;
    Help1: TMenuItem;
    Introduction1: TMenuItem;
    N18: TMenuItem;
    Resetfileshits1: TMenuItem;
    Kickidleconnections1: TMenuItem;
    Connectionsinactivitytimeout1: TMenuItem;
    logOnVideoChk: TMenuItem;
    N19: TMenuItem;
    Clearfilesystem1: TMenuItem;
    HintsfornewcomersChk: TMenuItem;
    logUploadsChk: TMenuItem;
    only1instanceChk: TMenuItem;
    compressedbrowsingChk: TMenuItem;
    Numberofloggeduploads1: TMenuItem;
    logProgressChk: TMenuItem;
    Flagfilesaddedrecently1: TMenuItem;
    Flagasnew1: TMenuItem;
    confirmexitChk: TMenuItem;
    Donotlogaddress1: TMenuItem;
    N15: TMenuItem;
    Custom1: TMenuItem;
    noPortInUrlChk: TMenuItem;
    saveTotalsChk: TMenuItem;
    Findexternaladdress1: TMenuItem;
    findExtOnStartupChk: TMenuItem;
    DynamicDNSupdater1: TMenuItem;
    Custom2: TMenuItem;
    N21: TMenuItem;
    CJBtemplate1: TMenuItem;
    NoIPtemplate1: TMenuItem;
    DynDNStemplate1: TMenuItem;
    searchbetteripChk: TMenuItem;
    deletePartialUploadsChk: TMenuItem;
    Minimumdiskspace1: TMenuItem;
    Banthisaddress1: TMenuItem;
    modalOptionsChk: TMenuItem;
    Address2name1: TMenuItem;
    Resetnewflag1: TMenuItem;
    beepChk: TMenuItem;
    Renamepartialuploads1: TMenuItem;
    SelfTest1: TMenuItem;
    Opendirectlyinbrowser1: TMenuItem;
    maxDLs1: TMenuItem;
    Editresource1: TMenuItem;
    logBannedChk: TMenuItem;
    ToolButton2: TToolButton;
    modeBtn: TToolButton;
    Addfiles2: TMenuItem;
    Addfolder2: TMenuItem;
    Clearoptionsandquit1: TMenuItem;
    numberFilesOnUploadChk: TMenuItem;
    Upload2: TMenuItem;
    UninstallHFS1: TMenuItem;
    maxIPs1: TMenuItem;
    maxIPsDLing1: TMenuItem;
    keepBakUpdatingChk: TMenuItem;
    Autosaveevery1: TMenuItem;
    autoSaveOptionsChk: TMenuItem;
    Apachelogfileformat1: TMenuItem;
    SwitchON1: TMenuItem;
    loadSingleCommentsChk: TMenuItem;
    Bindroottorealfolder1: TMenuItem;
    Unbindroot1: TMenuItem;
    Switchtorealfolder1: TMenuItem;
    abortBtn: TToolButton;
    Seelastserverresponse1: TMenuItem;
    N5: TMenuItem;
    logOtherEventsChk: TMenuItem;
    supportDescriptionChk: TMenuItem;
    Showcustomizedoptions1: TMenuItem;
    useISOdateChk: TMenuItem;
    browseUsingLocalhostChk: TMenuItem;
    Addingfolder1: TMenuItem;
    askFolderKindChk: TMenuItem;
    defaultToVirtualChk: TMenuItem;
    defaultToRealChk: TMenuItem;
    enableNoDefaultChk: TMenuItem;
    RunHFSwhenWindowsstarts1: TMenuItem;
    trayInsteadOfQuitChk: TMenuItem;
    Addicons1: TMenuItem;
    Iconmasks1: TMenuItem;
    CopyURLwithpassword1: TMenuItem;
    CopyURLwithdifferentaddress1: TMenuItem;
    hisIPaddressisusedforURLbuilding1: TMenuItem;
    N20: TMenuItem;
    Acceptconnectionson1: TMenuItem;
    Anyaddress1: TMenuItem;
    autoCommentChk: TMenuItem;
    fingerprintsChk: TMenuItem;
    CopyURLwithfingerprint1: TMenuItem;
    recursiveListingChk: TMenuItem;
    Disable1: TMenuItem;
    logOnlyServedChk: TMenuItem;
    Fingerprints1: TMenuItem;
    saveNewFingerprintsChk: TMenuItem;
    Createfingerprintonaddition1: TMenuItem;
    encodePwdUrlChk: TMenuItem;
    pwdInPagesChk: TMenuItem;
    deleteDontAskChk: TMenuItem;
    Updates1: TMenuItem;
    updateDailyChk: TMenuItem;
    N22: TMenuItem;
    Howto1: TMenuItem;
    testerUpdatesChk: TMenuItem;
    Defaultsorting1: TMenuItem;
    Name1: TMenuItem;
    Size1: TMenuItem;
    Time1: TMenuItem;
    Hits1: TMenuItem;
    centralPnl: TPanel;
    splitV: TSplitter;
    browseBtn: TToolButton;
    Resettotals1: TMenuItem;
    Clearandresettotals1: TMenuItem;
    Dontlogsomefiles1: TMenuItem;
    preventLeechingChk: TMenuItem;
    NumberofdifferentIPaddresses1: TMenuItem;
    NumberofdifferentIPaddresseseverconnected1: TMenuItem;
    Addresseseverconnected1: TMenuItem;
    N24: TMenuItem;
    Allowedreferer1: TMenuItem;
    ToolButton4: TToolButton;
    oemForIonChk: TMenuItem;
    portBtn: TToolButton;
    resetOptions1: TMenuItem;
    quitWithoutAskingToSaveChk: TMenuItem;
    highSpeedChk: TMenuItem;
    freeLoginChk: TMenuItem;
    backupSavingChk: TMenuItem;
    graphMenu: TPopupMenu;
    Reset1: TMenuItem;
    Extension1: TMenuItem;
    linksBeforeChk: TMenuItem;
    updateAutomaticallyChk: TMenuItem;
    stopSpidersChk: TMenuItem;
    logPnl: TPanel;
    logBox: TRichEdit;
    filesPnl: TPanel;
    filesBox: TTreeView;
    logTitle: TPanel;
    filesTitle: TPanel;
    graphBox: TPaintBox;
    dumpTrafficChk: TMenuItem;
    httpsUrlsChk: TMenuItem;
    Hide: TMenuItem;
    Speedlimitforsingleaddress1: TMenuItem;
    macrosLogChk: TMenuItem;
    Debug1: TMenuItem;
    Appendmacroslog1: TMenuItem;
    preventStandbyChk: TMenuItem;
    titlePnl: TPanel;
    HTMLtemplate1: TMenuItem;
    Edit1: TMenuItem;
    Changefile1: TMenuItem;
    Changeeditor1: TMenuItem;
    Restoredefault1: TMenuItem;
    logToolbar: TPanel;
    splitH: TSplitter;
    collapsedPnl: TPanel;
    expandBtn: TSpeedButton;
    expandedPnl: TPanel;
    openLogBtn: TSpeedButton;
    searchPnl: TPanel;
    logSearchBox: TLabeledEdit;
    logUpDown: TUpDown;
    openFilteredLog: TSpeedButton;
    collapseBtn: TSpeedButton;
    copyBtn: TToolButton;
    urlBox: TEdit;
    Bevel1: TBevel;
    enableMacrosChk: TMenuItem;
    Donate1: TMenuItem;
    Purge1: TMenuItem;
    Editeventscripts1: TMenuItem;
    maxDLsIP1: TMenuItem;
    Maxlinesonscreen1: TMenuItem;
    Properties1: TMenuItem;
    N11: TMenuItem;
    restoreCfgBtn: TToolButton;
    N14: TMenuItem;
    Runscript1: TMenuItem;
    Changeport1: TMenuItem;
    logDeletionsChk: TMenuItem;
    showMemUsageChk: TMenuItem;
    trayiconforeachdownload1: TMenuItem;
    tabOnLogFileChk: TMenuItem;
    noContentdispositionChk: TMenuItem;
    Defaultpointtoaddfiles1: TMenuItem;
    switchMode: TMenuItem;
    sbar: TStatusBar;
    connBox: TListView;
    Reverttopreviousversion1: TMenuItem;
    updateBtn: TToolButton;
    delayUpdateChk: TMenuItem;
    oemTarChk: TMenuItem;
    procedure FormResize(Sender: TObject);
    procedure filesBoxCollapsing(Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean);
    procedure newfolder1Click(Sender: TObject);
    procedure filesBoxEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure filesBoxEdited(Sender: TObject; Node: TTreeNode; var S: String);
    procedure Remove1Click(Sender: TObject);
    procedure startBtnClick(Sender: TObject);
    procedure filesBoxChange(Sender: TObject; Node: TTreeNode);
    procedure Kickconnection1Click(Sender: TObject);
    procedure Kickallconnections1Click(Sender: TObject);
    procedure KickIPaddress1Click(Sender: TObject);
    procedure Viewhttprequest1Click(Sender: TObject);
    procedure connmenuPopup(Sender: TObject);
    procedure filemenuPopup(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure timerEvent(Sender: TObject);
    procedure menuPopup(Sender: TObject);
    procedure filesBoxDblClick(Sender: TObject);
    procedure filesBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure filesBoxCompare(Sender: TObject; Node1, Node2: TTreeNode;
      Data: Integer; var Compare: Integer);
    procedure foldersbeforeChkClick(Sender: TObject);
    procedure Browseit1Click(Sender: TObject);
    procedure Openit1Click(Sender: TObject);
    procedure splitVMoved(Sender: TObject);
    procedure appEventsShowHint(var HintStr: String;
      var CanShow: Boolean; var HintInfo: THintInfo);
    procedure logmenuPopup(Sender: TObject);
    procedure Readonly1Click(Sender: TObject);
    procedure Clear1Click(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure Saveas1Click(Sender: TObject);
    procedure Save1Click(Sender: TObject);
    procedure Clearoptionsandquit1click(Sender: TObject);
    procedure appEventsMinimize(Sender: TObject);
    procedure appEventsRestore(Sender: TObject);
    procedure Restore1Click(Sender: TObject);
    procedure Numberofcurrentconnections1Click(Sender: TObject);
    procedure Numberofloggeddownloads1Click(Sender: TObject);
    procedure Numberofloggedhits1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure onDownloadChkClick(Sender: TObject);
    procedure onconnectionChkClick(Sender: TObject);
    procedure never1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure filesBoxDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure filesBoxDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure Savefilesystem1Click(Sender: TObject);
    procedure filesBoxDeletion(Sender: TObject; Node: TTreeNode);
    procedure Loadfilesystem1Click(Sender: TObject);
    procedure leavedisconnectedconnectionsChkClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Officialwebsite1Click(Sender: TObject);
    procedure showmaintrayiconChkClick(Sender: TObject);
    procedure Speedlimit1Click(Sender: TObject);
    procedure tofile1Click(Sender: TObject);
    procedure Maxconnections1Click(Sender: TObject);
    procedure Maxconnectionsfromsingleaddress1Click(Sender: TObject);
    procedure Forum1Click(Sender: TObject);
    procedure FAQ1Click(Sender: TObject);
    procedure License1Click(Sender: TObject);
    procedure Paste1Click(Sender: TObject);
    procedure Addfiles1Click(Sender: TObject);
    procedure Addfolder1Click(Sender: TObject);
    procedure graphSplitterMoved(Sender: TObject);
    procedure Graphrefreshrate1Click(Sender: TObject);
    procedure Pausestreaming1Click(Sender: TObject);
    procedure Comment1Click(Sender: TObject);
    procedure filesBoxCustomDrawItem(Sender: TCustomTreeView;
      Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure Setuserpass1Click(Sender: TObject);
    procedure browseBtnClick(Sender: TObject);
    procedure BanIPaddress1Click(Sender: TObject);
    procedure BannedIPaddresses1Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Checkforupdates1Click(Sender: TObject);
    procedure Rename1Click(Sender: TObject);
    procedure Nodownloadtimeout1Click(Sender: TObject);
    procedure alwaysontopChkClick(Sender: TObject);
    procedure Showbandwidthgraph1Click(Sender: TObject);
    procedure Pause1Click(Sender: TObject);
    procedure MIMEtypes1Click(Sender: TObject);
    procedure Accounts1Click(Sender: TObject);
    procedure traymessage1Click(Sender: TObject);
    procedure Guide1Click(Sender: TObject);
    procedure filesBoxAddition(Sender: TObject; Node: TTreeNode);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Logfile1Click(Sender: TObject);
    procedure Font1Click(Sender: TObject);
    procedure Newlink1Click(Sender: TObject);
    procedure SetURL1Click(Sender: TObject);
    procedure Resetuserpass1Click(Sender: TObject);
    procedure Switchtovirtual1Click(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Loginrealm1Click(Sender: TObject);
    procedure Introduction1Click(Sender: TObject);
    procedure Resetfileshits1Click(Sender: TObject);
    procedure persistentconnectionsChkClick(Sender: TObject);
    procedure Kickidleconnections1Click(Sender: TObject);
    procedure Connectionsinactivitytimeout1Click(Sender: TObject);
    procedure splitHMoved(Sender: TObject);
    procedure Clearfilesystem1Click(Sender: TObject);
    procedure Numberofloggeduploads1Click(Sender: TObject);
    procedure Flagfilesaddedrecently1Click(Sender: TObject);
    procedure Flagasnew1Click(Sender: TObject);
    procedure Donotlogaddress1Click(Sender: TObject);
    procedure Custom1Click(Sender: TObject);
    procedure Findexternaladdress1Click(Sender: TObject);
    procedure sbarDblClick(Sender: TObject);
    procedure NoIPtemplate1Click(Sender: TObject);
    procedure Custom2Click(Sender: TObject);
    procedure CJBtemplate1Click(Sender: TObject);
    procedure DynDNStemplate1Click(Sender: TObject);
    procedure Minimumdiskspace1Click(Sender: TObject);
    procedure Banthisaddress1Click(Sender: TObject);
    procedure Address2name1Click(Sender: TObject);
    procedure Resetnewflag1Click(Sender: TObject);
    procedure Renamepartialuploads1Click(Sender: TObject);
    procedure SelfTest1Click(Sender: TObject);
    procedure Opendirectlyinbrowser1Click(Sender: TObject);
    procedure noPortInUrlChkClick(Sender: TObject);
    procedure maxDLs1Click(Sender: TObject);
    procedure MaxDLsIP1Click(Sender: TObject);
    procedure Editresource1Click(Sender: TObject);
    procedure modeBtnClick(Sender: TObject);
    procedure Shellcontextmenu1Click(Sender: TObject);
    procedure UninstallHFS1Click(Sender: TObject);
    procedure maxIPs1Click(Sender: TObject);
    procedure maxIPsDLing1Click(Sender: TObject);
    procedure Autosaveevery1Click(Sender: TObject);
    procedure CopyURL1Click(Sender: TObject);
    procedure Apachelogfileformat1Click(Sender: TObject);
    procedure Bindroottorealfolder1Click(Sender: TObject);
    procedure Unbindroot1Click(Sender: TObject);
    procedure Switchtorealfolder1Click(Sender: TObject);
    procedure abortBtnClick(Sender: TObject);
    procedure Seelastserverresponse1Click(Sender: TObject);
    procedure Showcustomizedoptions1Click(Sender: TObject);
    procedure useISOdateChkClick(Sender: TObject);
    procedure RunHFSwhenWindowsstarts1Click(Sender: TObject);
    procedure askFolderKindChkClick(Sender: TObject);
    procedure defaultToVirtualChkClick(Sender: TObject);
    procedure defaultToRealChkClick(Sender: TObject);
    procedure Addicons1Click(Sender: TObject);
    procedure Iconmasks1Click(Sender: TObject);
    procedure Anyaddress1Click(Sender: TObject);
    procedure filesBoxEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure CopyURLwithfingerprint1Click(Sender: TObject);
    procedure Disable1Click(Sender: TObject);
    procedure saveNewFingerprintsChkClick(Sender: TObject);
    procedure Createfingerprintonaddition1Click(Sender: TObject);
    procedure pwdInPagesChkClick(Sender: TObject);
    procedure Howto1Click(Sender: TObject);
    procedure Name1Click(Sender: TObject);
    procedure Size1Click(Sender: TObject);
    procedure Time1Click(Sender: TObject);
    procedure Hits1Click(Sender: TObject);
    procedure Resettotals1Click(Sender: TObject);
    procedure menuBtnClick(Sender: TObject);
    procedure Clearandresettotals1Click(Sender: TObject);
    procedure Dontlogsomefiles1Click(Sender: TObject);
    procedure NumberofdifferentIPaddresses1Click(Sender: TObject);
    procedure NumberofdifferentIPaddresseseverconnected1Click(Sender: TObject);
    procedure Addresseseverconnected1Click(Sender: TObject);
    procedure Allowedreferer1Click(Sender: TObject);
    procedure filesBoxEnter(Sender: TObject);
    procedure filesBoxMouseEnter(Sender: TObject);
    procedure filesBoxMouseLeave(Sender: TObject);
    procedure filesBoxExit(Sender: TObject);
    procedure sbarMouseDown(Sender: TObject; Button: TMouseButton; shift: TShiftState; X, Y: Integer);
    procedure portBtnClick(Sender: TObject);
    procedure SwitchON1Click(Sender: TObject);
    procedure resetOptions1Click(Sender: TObject);
    procedure Reset1Click(Sender: TObject);
    procedure Extension1Click(Sender: TObject);
    procedure findExtOnStartupChkClick(Sender: TObject);
    procedure openLogBtnClick(Sender: TObject);
    procedure logSearchBoxKeyPress(Sender: TObject; var Key: Char);
    procedure graphBoxPaint(Sender: TObject);
    procedure logUpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure logSearchBoxChange(Sender: TObject);
    procedure HideClick(Sender: TObject);
    procedure Speedlimitforsingleaddress1Click(Sender: TObject);
    procedure Edit1Click(Sender: TObject);
    procedure Restoredefault1Click(Sender: TObject);
    procedure Changefile1Click(Sender: TObject);
    procedure Changeeditor1Click(Sender: TObject);
    procedure expandBtnClick(Sender: TObject);
    procedure collapseBtnClick(Sender: TObject);
    procedure copyBtnClick(Sender: TObject);
    procedure urlBoxChange(Sender: TObject);
    procedure enableMacrosChkClick(Sender: TObject);
    procedure Donate1Click(Sender: TObject);
    procedure Purge1Click(Sender: TObject);
    procedure Editeventscripts1Click(Sender: TObject);
    procedure Maxlinesonscreen1Click(Sender: TObject);
    procedure Properties1Click(Sender: TObject);
    procedure filesBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure restoreCfgBtnClick(Sender: TObject);
    procedure Runscript1Click(Sender: TObject);
    procedure logBoxChange(Sender: TObject);
    procedure logBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Changeport1Click(Sender: TObject);
    procedure trayiconforeachdownload1Click(Sender: TObject);
    procedure Defaultpointtoaddfiles1Click(Sender: TObject);
    function appEventsHelp(Command: Word; Data: Integer;
      var CallHelp: Boolean): Boolean;
    procedure connBoxData(Sender: TObject; Item: TListItem);
    procedure connBoxAdvancedCustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure Reverttopreviousversion1Click(Sender: TObject);
    procedure updateBtnClick(Sender: TObject);
  private
    function searchLog(dir: integer): boolean;
    function getGraphPic(cd: TconnData = NIL): string;
    procedure WMDropFiles(var msg: TWMDropFiles);
    message WM_DROPFILES;
    procedure WMQueryEndSession(var msg: TWMQueryEndSession);
    message WM_QUERYENDSESSION;
    procedure WMEndSession(var msg: TWMEndSession);
    message WM_ENDSESSION;
    procedure WMNCLButtonDown(var msg: TWMNCLButtonDown);
    message WM_NCLBUTTONDOWN;
    procedure trayEvent(sender: Tobject; ev: TtrayEvent);
    procedure downloadtrayEvent(sender: Tobject; ev: TtrayEvent);
    procedure httpEvent(event: ThttpEvent; conn: ThttpConn);
    function addFileRecur(f: Tfile; parent: Ttreenode = NIL): Tfile;
    function pointedFile(strict: boolean = TRUE): Tfile;
    function pointedConnection(): TconnData;
    procedure updateSbar();
    function getFolderPage(folder: Tfile; cd: TconnData; otpl: Tobject): string;
    procedure getPage(sectionName: string; data: TconnData; f: Tfile = NIL;
      tpl2use: TTemplate = NIL);
    function selectedConnection(): TconnData;
    function sendPic(cd: TconnData; idx: integer = -1): boolean;
    procedure ipmenuclick(sender: Tobject);
    procedure acceptOnMenuclick(sender: Tobject);
    procedure copyURLwithAddressMenuClick(sender: Tobject);
    procedure copyURLwithPasswordMenuClick(sender: Tobject);
    procedure updateTrayTip();
    procedure updateCopyBtn();
    procedure setTrayShows(s: string);
    procedure addTray();
    procedure refreshConn(conn: TconnData);
    function getVFS(node: Ttreenode = NIL): string;
    procedure setVFS(vfs: string; node: Ttreenode = NIL);
    procedure setnoDownloadTimeout(v: integer);
    procedure addDropFiles(hnd: Thandle; under: Ttreenode);
    procedure pasteFiles();
    function addFilesFromString(files: string; under: Ttreenode = NIL): Tfile;
    procedure setGraphRate(v: integer);
    procedure updateRecentFilesMenu();
    procedure recentsClick(sender: Tobject);
    procedure popupMainMenu();
    procedure updateAlwaysOnTop();
    procedure initVFS();
    procedure refreshIPlist();
    procedure updateUrlBox();
    procedure loadVFS(fn: string);
    procedure compressReply(cd: TconnData);
    procedure purgeConnections();
    procedure setEasyMode(easy: boolean = TRUE);
    procedure hideGraph();
    procedure showGraph();
    function fileAttributeInSelection(fa: TfileAttribute): boolean;
    procedure progFrmHttpGetUpdate(sender: Tobject; buffer: pointer;
      Len: integer);
    procedure recalculateGraph();
  public
    procedure remove(node: Ttreenode = NIL);
    function setCfg(cfg: string; alreadyStarted: boolean = TRUE): boolean;
    function getCfg(exclude: string = ''): string;
    function saveCFG(): boolean;
    function addFile(f: Tfile; parent: Ttreenode = NIL;
      skipComment: boolean = FALSE): Tfile;
    procedure add2log(lines: string; cd: TconnData = NIL;
      clr: Tcolor = clDefault);
    function findFilebyURL(url: string; parent: Tfile = NIL;
      allowTemp: boolean = TRUE): Tfile;
    function ipPointedInLog(): string;
    procedure saveVFS(fn: string = '');
    function finalInit(): boolean;
    procedure processParams_after(var params: TStringDynArray);
    procedure setStatusBarText(s: string; lastFor: integer = 5);
    procedure minimizeToTray();
    procedure autoCheckUpdates();
    function copySelection(): TtreeNodeDynArray;
    procedure setLogToolbar(v: boolean);
    function getTrayTipMsg(tpl: string = ''): string;
    procedure menuDraw(sender: Tobject; cnv: Tcanvas; r: Trect;
      selected: boolean);
    procedure menuMeasure(sender: Tobject; cnv: Tcanvas; var w: integer;
      var h: integer);
  end; // Tmainfrm

  TBanRecord = record
    ip, comment: string;
  end;

const
  FILEACTION2STR: array [TfileAction] of string = ('Access', 'Delete', 'Upload');

var
  mainFrm: TmainFrm;
  srv: ThttpSrv;
  Template: TTemplate; // template for generated pages
  customIPs: TStringDynArray; // user customized IP addresses
  iconMasks: TstringIntPairs;
  ipsEverConnected: THashedStringList;
  easyMode: boolean = TRUE;
  defaultIP: string; // the IP address to use forming URLs
  rootNode: TtreeNode;
  rootFile: Tfile;
  noReplyBan: boolean;
  exePath: string;
  externalIP: string;
  banlist: array of TBanRecord;
  trayMsg: string; // template for the tray hint
  customIPservice: string;
  accounts: Taccounts;
  tplFilename: string; // when empty, we are using the default tpl
  trayNL: string = #13;
  mimeTypes, address2name, IPservices: TStringDynArray;
  IPservicesTime: TdateTime;
  selectedFile: Tfile; // last selected file on the tree
  inBrowserIfMIME: boolean;
  VFSmodified: boolean; // TRUE if the VFS changes have not been saved
  tempScriptFilename: string;
  uploadPaths: TStringDynArray;
  inTotalOfs, outTotalOfs: int64; // used to cumulate in/out totals
  hitsLogged, downloadsLogged, uploadsLogged: integer;
  lastFileOpen: string;
  minDiskSpace: int64; // in MB. an int32 would suffice, but an int64 will save us
  speedLimit: real; // overall limit, Kb/s --- it virtualizes the value of globalLimiter.maxSpeed, that's actually set to zero when streaming is paused
  currentCFG: string;
  currentCFGhashed: THashedStringList;
  saveMode: (SM_USER, SM_SYSTEM, SM_FILE);
  tray: TmyTrayicon;
  dyndns: record url, lastResult, lastIP: string;
  user, pwd, host: string;
  active: boolean;
  lastTime: TdateTime;
end;

procedure showOptions(page: TtabSheet);
procedure kickBannedOnes();
procedure repaintTray();
function paramsAsArray(): TStringDynArray;
procedure processParams_before(var params: TStringDynArray;
  allowed: string = '');
function loadCfg(var ini, tpl: string): boolean;
function idx_img2ico(i: integer): integer;
function idx_ico2img(i: integer): integer;
function idx_label(i: integer): string;
function findEnabledLinkedAccount(account: Paccount; over: TStringDynArray;
  isSorted: boolean = FALSE): Paccount;
function getImageIndexForFile(fn: string): integer;
function conn2data(i: integer): TconnData; inline; overload;
function uptimestr(): string;
function countIPs(onlyDownloading: boolean = FALSE;
  usersInsteadOfIps: boolean = FALSE): integer;
function getSafeHost(cd: TconnData): string;
function localDNSget(ip: string): string;
function countDownloads(ip: string = ''; user: string = '';
  f: Tfile = NIL): integer;
function accountAllowed(action: TfileAction; cd: TconnData; f: Tfile): boolean;
function getAccountList(users: boolean = TRUE; groups: boolean = TRUE)
  : TStringDynArray;
function fileExistsByURL(url: string): boolean;
function createFingerprint(fn: string): string;
function objByIP(ip: string): TperIp;
function protoColon(): string;
procedure setSpeedLimitIP(v: real);
procedure stopServer();
function startServer(): boolean;
function deleteAccount(name: string): boolean;

implementation

{$R *.dfm}
{$R data.res}

uses
  newuserpassDlg, optionsDlg, Rejetto.Utils, folderKindDlg, shellExtDlg, diffDlg, ipsEverDlg, Rejetto.Parser, MMsystem,
  Vcl.Imaging.GIFImg,
  purgeDlg, filepropDlg, runscriptDlg, Rejetto.Script;

type
  Tsysidx2Record = record
    sysidx, idx: integer;
  end;

// global variables
var
  globalLimiter: TspeedLimiter;
  ip2obj: THashedStringList;
  sessions: THashedStringList;
  addToFolder: string; // default folder where to add items from the command line
  lastDialogFolder: string;  // stores last for open dialog, to make it persistent
  clock: integer;       // program ticks (tenths of second)
  // workaround for splitters' bad behaviour
  lastGoodLogWidth, lastGoodConnHeight: integer;
  etags: THashedStringList;
  tray_ico: Ticon;             // the actual icon shown in tray
  usingFreePort: boolean=TRUE; // the actual server port set was 0
  upTime: Tdatetime;           // the server is up since...
  trayed: boolean;             // true if the window has been minimized to tray
  trayShows: string;           // describes the content of the tray icon
  flashOn: string;             // describes when to flash the taskbar
  addFolderDefault: string;    // how to default adding a folder (real/virtual)
  defSorting: string;          // default sorting, browsing
  toDelete: Tlist;             // connections pending for deletion
  systemimages: Timagelist;    // system icons
  speedLimitIP: real;
  maxConnections: integer;     // max number of connections (total)
  maxConnectionsIP: integer;   // ...from a single address
  maxContempDLs: integer;      // max number of contemporaneous downloads
  maxContempDLsIP: integer;    // ...from a single address
  maxContempDLsUser: integer;  // ...from a single user
  maxIPs: integer;             // max number of different addresses connected
  maxIPsDLing: integer;        // max number of different addresses downloading
  autoFingerprint: integer;    // create fingerprint on file addition
  renamePartialUploads: string;
  allowedReferer: string;      // check over the Refer header field
  altPressedForMenu: boolean;  // used to enable the menu on ALT key
  noDownloadTimeout: integer;  // autoclose the application after (minutes)
  connectionsInactivityTimeout: integer; // autokick connection after (seconds)
  startingImagesCount: integer;
  lastUpdateCheck, lastFilelistTpl: Tdatetime;
  lastUpdateCheckFN: string;   // eventual temp file for saving lastUpdateCheck
  lastActivityTime: Tdatetime;  // used for the "no download timeout"
  recentFiles: TStringDynArray; // recently loaded files
  addingItemsCounter: integer = -1; // -1 is disabled
  stopAddingItems, queryingClose: boolean;
  port: string;
  defaultTpl: string;
  tpl_help: string;
  lastWindowRect: Trect;
  dmBrowserTpl, filelistTpl: TTemplate;
  tplEditor: string;
  tplLast: Tdatetime;
  tplImport: boolean;
  eventScriptsLast, runScriptLast: Tdatetime;
  autoupdatedFiles: TstringToIntHash;   // download counter for temp Tfile.s
  iconsCache: TiconsCache;
  usersInVFS: TusersInVFS;    // keeps track of user/pwd in the VFS
  progFrm: TprogressForm;
  graphInEasyMode: boolean;
  cfgPath, tmpPath: string;
  logMaxLines: integer;     // number of lines
  windowsShuttingDown: boolean = FALSE;
  dontLogAddressMask: string;
  openInBrowser: string; // to not send the "attachment" suggestion in header
  quitASAP: boolean;  // deferred quit
  quitting: boolean; // ladies, we're quitting
  scrollFilesBox: integer = -1;
  defaultCfg: string;
  selfTesting: boolean;
  tplIsCustomized: boolean;
  fakingMinimize: boolean; // user clicked the [X] but we simulate the [_]
  sysidx2index: array of Tsysidx2Record; // maps system imagelist icons to internal imagelist
  loginRealm: string;
  serializedConnColumns: string;
  VFScounterMod: boolean; // if any counter has changed
  imagescache: array of string;
  logFontName: string;
  logFontSize: integer;
  forwardedMask: string;
  applicationFullyInitialized: boolean;
  lockTimerevent: boolean;
  filesStayFlaggedForMinutes: integer;
  autosaveVFS: Tautosave;
  logRightClick: Tpoint;
  warnManyItems: boolean = TRUE;
  runningOnRemovable: boolean;
  startupFilename: string;
  trustedFiles, filesToAddQ: TstringDynArray;
  setThreadExecutionState: function(d:dword):dword; stdcall; // as variable, because not available on Win95
  listenOn: string;  // interfaces HFS should listen on
  backuppedCfg: string;
  updateASAP: string;
  refusedUpdate: string;
  updateWaiting: string;
  filesBoxRatio: real;
  fromTray: boolean; // used to notify about an eventy happening from a tray action
  userInteraction: record
    disabled: boolean;
    bakVisible: boolean;  // backup value for mainFrm.visible
  end;
  logFile: record
    filename: string;
    apacheFormat: string;
    apacheZoneString: string;
  end;
  loadingVFS: record
    resetLetBrowse, unkFK, disableAutosave, visOnlyAnon, bakAvailable, useBackup, macrosFound: boolean;
    build: string;
  end;
  lastDiffTpl: record
    f: Tfile;
    ofs: integer;
  end;
  userIcsBuffer, userSocketBuffer: integer;
  searchLogTime, searchLogWhiteTime, timeTookToSearchLog: TdateTime;
  sbarTextTimeout: Tdatetime;
  sbarIdxs: record  // indexes within the statusbar
    totalIn, totalOut, banStatus, customTpl, oos, out, notSaved: integer;
  end;
  graph: record
  	rate: integer;    // update speed
    lastOut, lastIn: int64; // save bytesSent and bytesReceived last values
    maxV: integer;    // max value in scale
    size: integer;    // height of the box
    samplesIn, samplesOut: array [0..3000] of integer; // 1 sample, 1 pixel
    beforeRecalcMax: integer;  // countdown
  end;

var
  dll: HMODULE;

type
  TaccountRecursionStopCase = (ARSC_REDIR, ARSC_NOLIMITS, ARSC_IN_SET);

function deleteAccount(name: string): boolean;
var
  i, j, n: integer;
begin
  n := length(accounts);
  // search
  for i := 0 to n - 1 do
    if sameText(name, accounts[i].user) then // found
    begin
      // shift
      for j := i to n - 2 do
        accounts[j] := accounts[j + 1];
      // shrink
      setLength(accounts, n - 1);
      // aftermaths
      purgeVFSaccounts();
      mainfrm.filesBox.repaint();
      result := TRUE;
      exit;
    end;
  result := FALSE;
end; // deleteAccount

function isCommentFile(fn: string): boolean;
begin
  result := (fn = COMMENTS_FILE) or mainfrm.loadSingleCommentsChk.checked and
    isExtension(fn, COMMENT_FILE_EXT) or
    mainfrm.supportDescriptionChk.checked and sameText('descript.ion', fn)
end; // isCommentFile

function isFingerprintFile(fn: string): boolean;
begin
  result := mainfrm.fingerprintsChk.checked and isExtension(fn, '.md5')
end; // isFingerprintFile

// this function follows account linking until it finds and returns the account matching the stopCase
function accountRecursion(account: Paccount;
  stopCase: TaccountRecursionStopCase; data: pointer = NIL;
  data2: pointer = NIL): Paccount;

  function shouldStop(): boolean;
  begin
    case stopCase of
      ARSC_REDIR:
        result := account.redir > '';
      ARSC_NOLIMITS:
        result := account.noLimits;
      ARSC_IN_SET:
        result := stringExists(account.user, TstringDynArray(data),
          boolean(data2));
    else
      result := FALSE;
    end;
  end;

var
  tocheck: TstringDynArray;
  i: integer;
begin
  result := NIL;
  if (account = NIL) or not account.enabled then
    exit;
  if shouldStop() then
  begin
    result := account;
    exit;
  end;
  i := 0;
  tocheck := account.link;
  while i < length(tocheck) do
  begin
    account := getAccount(tocheck[i], TRUE);
    inc(i);
    if (account = NIL) or not account.enabled then
      continue;
    if shouldStop() then
    begin
      result := account;
      exit;
    end;
    addUniqueArray(tocheck, account.link);
  end;
end; // accountRecursion

function findEnabledLinkedAccount(account: Paccount; over: TstringDynArray;
  isSorted: boolean = FALSE): Paccount;
begin
  result := accountRecursion(account, ARSC_IN_SET, over, boolToPtr(isSorted))
end;

function noLimitsFor(account: Paccount): boolean;
begin
  account := accountRecursion(account, ARSC_NOLIMITS);
  result := assigned(account) and account.noLimits;
end; // noLimitsFor

function accountAllowed(action: TfileAction; cd: TconnData; f: Tfile): boolean;
var
  a: TstringDynArray;
begin
  result := FALSE;
  if f = NIL then
    exit;
  if action = FA_ACCESS then
  begin
    result := f.accessFor(cd);
    exit;
  end;
  if f.isTemp() then
    f := f.parent;
  if (action = FA_UPLOAD) and not f.isRealFolder() then
    exit;

  repeat
    a := f.accounts[action];
    if assigned(a) and not((action = FA_UPLOAD) and not f.isRealFolder()) then
      break;
    f := f.parent;
    if f = NIL then
      exit;
  until FALSE;

  result := TRUE;
  if stringExists(USER_ANYONE, a, TRUE) then
    exit;
  result := (cd.usr = '') and stringExists(USER_ANONYMOUS, a, TRUE) or
    assigned(cd.account) and stringExists(USER_ANY_ACCOUNT, a, TRUE) or
    (NIL <> findEnabledLinkedAccount(cd.account, a, TRUE));
end; // accountAllowed

function hasRightAttributes(attr: integer): boolean; overload;
begin
  result := (mainfrm.listfileswithhiddenattributeChk.checked or
    (attr and faHidden = 0)) and
    (mainfrm.listfileswithsystemattributeChk.checked or
    (attr and faSysFile = 0));
end; // hasRightAttributes

function hasRightAttributes(fn: string): boolean; overload;
begin
  result := hasRightAttributes(GetFileAttributesA(pAnsiChar(ansiString(fn))))
end;

function isAnyMacroIn(s: string): boolean; inline;
begin
  result := pos(MARKER_OPEN, s) > 0
end;

function loadDescriptionFile(fn: string): string;
begin
  result := loadFile(fn);
  if result = '' then
    result := loadFile(fn + '\descript.ion');
  if (result > '') and mainfrm.oemForIonChk.checked then
    OEMToCharBuff(@result[1], @result[1], length(result));
end; // loadDescriptionFile

function escapeIon(s: string): string;
begin
  // this escaping method (and also the 2-bytes marker) was reverse-engineered from Total Commander
  result := escapeNL(s);
  if result <> s then
    result := result + #4#$C2;
end; // escapeIon

function unescapeIon(s: string): string;
begin
  if ansiEndsStr(#4#$C2, s) then
  begin
    setLength(s, length(s) - 2);
    s := unescapeNL(s);
  end;
  result := s;
end; // unescapeIon

function findNameInDescriptionFile(txt, name: string): integer;
begin
  result := reMatch(txt, '^' + quoteRegExprMetaChars(quoteIfAnyChar(' ',
    name)), 'mi')
end;

type
  TfileListing = class
  public
    dir: array of Tfile;
    ignoreConnFilter: boolean;
    constructor create();
    destructor Destroy; override;
    function fromFolder(folder: Tfile; cd: TconnData;
      recursive: boolean = FALSE; limit: integer = -1; toSkip: integer = -1;
      doClear: boolean = TRUE): integer;
    procedure sort(cd: TconnData; def: string = '');
  end;

constructor TfileListing.create();
begin
  dir := NIL;
end; // create

destructor TfileListing.Destroy;
var
  i: integer;
begin
  for i := 0 to length(dir) - 1 do
    freeIfTemp(dir[i]);
  inherited Destroy;
end; // destroy

procedure TfileListing.sort(cd:TconnData; def:string='');
var
  foldersBefore, linksBefore, rev: boolean;
  sortBy: ( SB_NAME, SB_EXT, SB_SIZE, SB_TIME, SB_DL, SB_COMMENT );

  function compareExt(f1, f2: string): integer;
  begin
    result := ansiCompareText(extractFileExt(f1), extractFileExt(f2))
  end;

  function compareFiles(item1, item2: pointer): integer;
  var
    f1, f2: Tfile;
  begin
    f1 := item1;
    f2 := item2;
    if linksBefore and (f1.isLink() <> f2.isLink()) then
    begin
      if f1.isLink() then
        result := -1
      else
        result := +1;
      exit;
    end;
    if foldersBefore and (f1.isFolder() <> f2.isFolder()) then
    begin
      if f1.isFolder() then
        result := -1
      else
        result := +1;
      exit;
    end;
    result := 0;
    case sortBy of
      SB_SIZE:
        result := compare_(f1.size, f2.size);
      SB_TIME:
        result := compare_(f1.mtime, f2.mtime);
      SB_DL:
        result := compare_(f1.DLcount, f2.DLcount);
      SB_EXT:
        if not f1.isFolder() and not f2.isFolder() then
          result := compareExt(f1.name, f2.name);
      SB_COMMENT:
        result := ansiCompareText(f1.comment, f2.comment);
    end;
    if result = 0 then
    // this happen both for SB_NAME and when other comparisons result in no difference
      result := ansiCompareText(f1.name, f2.name);
    if rev then
      result := -result;
  end; // compareFiles

  procedure qsort(left, right: integer);
  var
    split, t: Tfile;
    i, j: integer;
  begin
    if left >= right then
      exit;
    application.ProcessMessages();
    if cd.conn.state = HCS_DISCONNECTED then
      exit;

    i := left;
    j := right;
    split := dir[(i + j) div 2];
    repeat
      while compareFiles(dir[i], split) < 0 do
        inc(i);
      while compareFiles(split, dir[j]) < 0 do
        dec(j);
      if i <= j then
      begin
        t := dir[i];
        dir[i] := dir[j];
        dir[j] := t;

        inc(i);
        dec(j);
      end
      until i > j;
      if left < j then
        qsort(left, j);
      if i < right then
        qsort(i, right);
    end; // qsort

  procedure check1(var flag: boolean; val: string);
  begin
    if val > '' then
      flag := val = '1'
  end;

var
  v: string;
begin
  // caching
  foldersBefore := mainfrm.foldersBeforeChk.checked;
  linksBefore := mainfrm.linksBeforeChk.checked;

  v := first([def, defSorting, 'name']);
  rev := FALSE;
  if assigned(cd) then
    with cd.urlvars do
    begin
      v := first(values['sort'], v);
      rev := values['rev'] = '1';

      check1(foldersBefore, values['foldersbefore']);
      check1(linksBefore, values['linksbefore']);
    end;
  if ansiStartsStr('!', v) then
  begin
    delete(v, 1, 1);
    rev := not rev;
  end;
  if v = '' then
    exit;
  case v[1] of
    'n': sortBy := SB_NAME;
    'e': sortBy := SB_EXT;
    's': sortBy := SB_SIZE;
    't': sortBy := SB_TIME;
    'd': sortBy := SB_DL;
    'c': sortBy := SB_COMMENT;
  else
    exit; // unsupported value
  end;
  qsort(0, length(dir) - 1);
end; // sort


procedure loadIon(path: string; comments: TstringList);
var
  s, l, fn: string;
begin
  if not mainfrm.supportDescriptionChk.checked then
    exit;
  s := loadDescriptionFile(path);
  while s > '' do
  begin
    l := chopLine(s);
    if l = '' then
      continue;
    fn := chop(nonQuotedPos(' ', l), l);
    comments.add(dequote(fn) + '=' + trim(unescapeIon(l)));
  end;
end; // loadIon

// returns number of skipped files
function TfileListing.fromFolder(folder: Tfile; cd: TconnData;
  recursive: boolean = FALSE; limit: integer = -1; toSkip: integer = -1;
  doClear: boolean = TRUE): integer;
var
  actualCount: integer;
  seeProtected, noEmptyFolders, forArchive: boolean;
  filesFilter, foldersFilter, urlFilesFilter, urlFoldersFilter: string;

  procedure recurOn(f: Tfile);
  begin
    if not f.isFolder() then
      exit;
    setLength(dir, actualCount);
    toSkip := fromFolder(f, cd, TRUE, limit, toSkip, FALSE);
    actualCount := length(dir);
  end; // recurOn

  procedure addToListing(f: Tfile);
  begin
    if noEmptyFolders and f.isEmptyFolder(cd) and not accountAllowed(FA_UPLOAD,
      cd, f) then
      exit; // upload folders should be listed anyway
    application.ProcessMessages();
    if cd.conn.state = HCS_DISCONNECTED then
      exit;

    if toSkip > 0 then
      dec(toSkip)
    else
    begin
      if actualCount >= length(dir) then
        setLength(dir, actualCount + 100);
      dir[actualCount] := f;
      inc(actualCount);
    end;

    if recursive and f.isFolder() then
      recurOn(f);
  end; // addToListing

  function allowedTo(f: Tfile): boolean;
  begin
    if cd = NIL then
      result := FALSE
    else
      result := (not(FA_VIS_ONLY_ANON in f.flags) or (cd.usr = '')) and
        (seeProtected or f.accessFor(cd)) and
        not(forArchive and f.isDLforbidden())
  end; // allowedTo

  procedure includeFilesFromDisk();
  var
    comments: THashedStringList;
    commentMasks: TStringDynArray;

    // moves to "commentMasks" comments with a filemask as filename
    procedure extractCommentsWithWildcards();
    var
      i: integer;
      s: string;
    begin
      i := 0;
      while i < comments.count do
      begin
        s := comments.names[i];
        if ansiContainsStr(s, '?') or ansiContainsStr(s, '*') then
        begin
          addString(comments[i], commentMasks);
          comments.Delete(i);
        end
        else
          inc(i);
      end;
    end; // extractCommentsWithWildcards

  // extract comment for "fn" from "commentMasks"
    function getCommentByMaskFor(fn: string): string;
    var
      i: integer;
      s, mask: string;
    begin
      for i := 0 to length(commentMasks) - 1 do
      begin
        s := commentMasks[i];
        mask := chop('=', s);
        if fileMatch(mask, fn) then
        begin
          result := s;
          exit;
        end;
      end;
      result := '';
    end; // getCommentByMaskFor

    procedure setBit(var i: integer; bits: integer; flag: boolean); inline;
    begin
      if flag then
        i := i or bits
      else
        i := i and not bits;
    end; // setBit

  { **

    this would let us have "=" inside the names, but names cannot be assigned

    procedure fixQuotedStringList(sl:Tstrings);
    var
    i: integer;
    s: string;
    begin
    for i:=0 to sl.count-1 do
    begin
    s:=sl.names[i];
    if (s = '') or (s[1] <> '"') then continue;
    s:=s+'='+sl.ValueFromIndex[i]; // reconstruct the line
    sl.names[i]:=chop(nonQuotedPos('=', s), s);
    sl.ValueFromIndex[i]:=s;
    end;
    end;
  }
  var
    f: Tfile;
    sr: TSearchRec;
    namesInVFS: TStringDynArray;
    n: TtreeNode;
    filteredOut: boolean;
    i: integer;
  begin
    if (limit >= 0) and (actualCount >= limit) then
      exit;

    // collect names in the VFS at this level. supposed to be faster than existsNodeWithName().
    namesInVFS := NIL;
    n := folder.node.getFirstChild();
    while assigned(n) do
    begin
      addString(n.text, namesInVFS);
      n := n.getNextSibling();
    end;

    comments := THashedStringList.create();
    try
      comments.caseSensitive := FALSE;
      try
        comments.loadFromFile(folder.resource + '\' + COMMENTS_FILE);
      except
      end;
      loadIon(folder.resource, comments);
      i := if_((filesFilter = '\') or (urlFilesFilter = '\'), faDirectory,
        faAnyFile);
      setBit(i, faSysFile, mainfrm.listfileswithsystemattributeChk.checked);
      setBit(i, faHidden, mainfrm.listfileswithHiddenAttributeChk.checked);
      if findfirst(folder.resource + '\*', i, sr) <> 0 then
        exit;

      try
        extractCommentsWithWildcards();
        repeat
          application.ProcessMessages();
          cd.lastActivityTime := now();
          // we don't list these entries
          if (sr.name = '.') or (sr.name = '..') or isCommentFile(sr.name) or
            isFingerprintFile(sr.name) or sameText(sr.name, DIFF_TPL_FILE) or
            not hasRightAttributes(sr.attr) or stringExists(sr.name, namesInVFS)
          then
            continue;

          filteredOut := not fileMatch(if_(sr.attr and faDirectory > 0,
            foldersFilter, filesFilter), sr.name) or
            not fileMatch(if_(sr.attr and faDirectory > 0, urlFoldersFilter,
            urlFilesFilter), sr.name);
          // if it's a folder, though it was filtered, we need to recur
          if filteredOut and (not recursive or (sr.attr and faDirectory = 0))
          then
            continue;

          f := Tfile.createTemp(folder.resource + '\' + sr.name);
          f.node := folder.node;
          // temporary nodes are bound to the parent's node
          if (FA_SOLVED_LNK in f.flags) and f.isFolder() then
          // sorry, but we currently don't support lnk to folders in real-folders
          begin
            f.free;
            continue;
          end;
          if filteredOut then
          begin
            recurOn(f);
            // possible children added during recursion are linked back through the node field, so we can safely free the Tfile
            f.free;
            continue;
          end;

          f.comment := comments.values[sr.name];
          if f.comment = '' then
            f.comment := getCommentByMaskFor(sr.name);
          f.comment := macroQuote(unescapeNL(f.comment));

          f.size := 0;
          if f.isFile() then
            if FA_SOLVED_LNK in f.flags then
              f.size := sizeOfFile(f.resource)
            else
              f.size := sr.FindData.nFileSizeLow +
                int64(sr.FindData.nFileSizeHigh) shl 32;
          f.mtime := filetimeToDatetime(sr.FindData.ftLastWriteTime);
          addToListing(f);
        until (findNext(sr) <> 0) or (cd.conn.state = HCS_DISCONNECTED) or
          (limit >= 0) and (actualCount >= limit);
      finally
        findClose(sr)
      end;
    finally
      comments.free
    end
  end; // includeFilesFromDisk

  procedure includeItemsFromVFS();
  var
    f: Tfile;
    sr: TSearchRec;
    n: TtreeNode;
  begin
    { this folder has been dinamically generated, thus the node is not actually
      { its own... skip }
    if folder.isTemp() then
      exit;

    // include (valid) items from the VFS branch
    n := folder.node.getFirstChild();
    while assigned(n) and (cd.conn.state <> HCS_DISCONNECTED) and
      ((limit < 0) or (actualCount < limit)) do
    begin
      cd.lastActivityTime := now();

      f := n.data;
      n := n.getNextSibling();

      // watching not allowed, to anyone
      if (FA_HIDDEN in f.flags) or (FA_HIDDENTREE in f.flags) then
        continue;

      // filtered out
      if not fileMatch(if_(f.isFolder(), foldersFilter, filesFilter), f.name) or
        not fileMatch(if_(f.isFolder(), urlFoldersFilter,
        urlFilesFilter), f.name)
      // in this case we must continue recurring: other virtual items may be contained in this real folder, and this flag doesn't apply to them.
        or (forArchive and f.isRealFolder() and (FA_DL_FORBIDDEN in f.flags))
      then
      begin
        if recursive then
          recurOn(f);
        continue;
      end;

      if not allowedTo(f) then
        continue;

      if FA_VIRTUAL in f.flags then // links and virtual folders are virtual
      begin
        addToListing(f);
        continue;
      end;
      if FA_UNIT in f.flags then
      begin
        if System.SysUtils.DirectoryExists(f.resource + '\') then
          addToListing(f);
        continue;
      end;

      // try to get more info about this item
      if findfirst(f.resource, faAnyFile, sr) = 0 then
      begin
        try
          // update size and time
          with sr.FindData do
            f.size := nFileSizeLow + int64(nFileSizeHigh) shl 32;
          try
            f.mtime := filetimeToDatetime(sr.FindData.ftLastWriteTime);
          except
            f.mtime := 0
          end;
        finally
          findClose(sr)
        end;
        if not hasRightAttributes(sr.attr) then
          continue;
      end
      else // why findFirst() failed? is it a shared folder?
        if not System.SysUtils.DirectoryExists(f.resource) then
          continue;
      addToListing(f);
    end;
  end; // includeItemsFromVFS

  function beginsOrEndsBy(ss: string; s: string): boolean;
  begin
    result := ansiStartsText(ss, s) or ansiEndsText(ss, s)
  end;

  function par(k: string): string;
  begin
    if cd = NIL then
      result := ''
    else
      result := cd.urlvars.values[k]
  end;

begin
  result := toSkip;
  if doClear then
    dir := NIL;

  if not folder.isFolder() or not folder.accessFor(cd) or
    folder.hasRecursive(FA_HIDDENTREE) or not(FA_BROWSABLE in folder.flags) then
    exit;

  if assigned(cd) then
  begin
    if limit < 0 then
      limit := StrToIntDef(par('limit'), -1);
    if toSkip < 0 then
      toSkip := StrToIntDef(par('offset'), -1);
    if toSkip < 0 then
      toSkip := max(0, pred(StrToIntDef(par('page'), 1)) * limit);
  end;

  actualCount := length(dir);
  folder.getFiltersRecursively(filesFilter, foldersFilter);
  if assigned(cd) and not ignoreConnFilter then
  begin
    urlFilesFilter := par('files-filter');
    if urlFilesFilter = '' then
      urlFilesFilter := par('filter');
    urlFoldersFilter := par('folders-filter');
    if urlFoldersFilter = '' then
      urlFoldersFilter := par('filter');
    if (urlFilesFilter + urlFoldersFilter = '') and (par('search') > '') then
    begin
      urlFilesFilter := reduceSpaces(par('search'), '*');
      if not beginsOrEndsBy('*', urlFilesFilter) then
        urlFilesFilter := '*' + urlFilesFilter + '*';
      urlFoldersFilter := urlFilesFilter;
    end;
  end;
  // cache user options
  forArchive := assigned(cd) and (cd.downloadingWhat = DW_ARCHIVE);
  seeProtected := not mainfrm.hideProtectedItemsChk.checked and not forArchive;
  noEmptyFolders := (urlFilesFilter = '') and
    folder.hasRecursive(FA_HIDE_EMPTY_FOLDERS);
  try
    if folder.isRealFolder() and not(FA_HIDDENTREE in folder.flags) and
      allowedTo(folder) then
      includeFilesFromDisk();
    includeItemsFromVFS();
  finally
    setLength(dir, actualCount)
  end;
  result := toSkip;
end; // fromFolder

function isDownloading(data: TconnData): boolean;
begin
  result := assigned(data) and data.countAsDownload and
    (data.conn.state in [HCS_REPLYING_BODY, HCS_REPLYING_HEADER, HCS_REPLYING])
end; // isDownloading

function isSendingFile(data: TconnData): boolean;
begin
  result := assigned(data) and (data.conn.state = HCS_REPLYING_BODY) and
    (data.conn.reply.bodyMode in [RBM_FILE, RBM_STREAM]) and
    (data.downloadingWhat in [DW_FILE, DW_ARCHIVE])
end; // isSendingFile

function isReceivingFile(data: TconnData): boolean;
begin
  result := assigned(data) and (data.conn.state = HCS_POSTING) and
    (data.uploadSrc > '')
end;

function conn2data(p: Tobject): TconnData; inline; overload;
begin
  if p = NIL then
    result := NIL
  else
    result := TconnData((p as ThttpConn).data)
end; // conn2data

function conn2data(i: integer): TconnData; inline; overload;
begin
  try
    if i < srv.conns.count then
      result := conn2data(srv.conns[i])
    else
      result := conn2data(srv.offlines[i - srv.conns.count])
  except
    result := NIL
  end
end; // conn2data

function conn2data(li: TlistItem): TconnData; inline; overload;
begin
  if li = NIL then
    result := NIL
  else
    result := conn2data(li.index)
end; // conn2data

function countConnectionsByIP(ip: string): integer;
var
  i: integer;
begin
  result := 0;
  i := 0;
  while i < srv.conns.count do
  begin
    if conn2data(i).address = ip then
      inc(result);
    inc(i);
  end;
end; // countConnectionsByIP

function countDownloads(ip: string = ''; user: string = '';
  f: Tfile = NIL): integer;
var
  i: integer;
  d: TconnData;
begin
  result := 0;
  i := 0;
  while i < srv.conns.count do
  begin
    d := conn2data(i);
    if isDownloading(d) and
      ((f = NIL) or (assigned(d.lastFile) and d.lastFile.same(f))) and
      ((ip = '') or addressMatch(ip, d.address)) and
      ((user = '') or sameText(user, d.usr)) then
      inc(result);
    inc(i);
  end;
end; // countDownloads

function countIPs(onlyDownloading: boolean = FALSE;
  usersInsteadOfIps: boolean = FALSE): integer;
var
  i: integer;
  d: TconnData;
  ips: TStringDynArray;
begin
  i := 0;
  ips := NIL;
  while i < srv.conns.count do
  begin
    d := conn2data(i);
    if not onlyDownloading or isDownloading(d) then
      addUniqueString(if_(usersInsteadOfIps, d.usr, d.address), ips);
    inc(i);
  end;
  result := length(ips);
end; // countIPs

function idx_img2ico(i: integer): integer;
begin
  if (i < startingImagesCount) or (i >= USER_ICON_MASKS_OFS) then
    result := i
  else
    result := i - startingImagesCount + USER_ICON_MASKS_OFS
end;

function idx_ico2img(i: integer): integer;
begin
  if i < USER_ICON_MASKS_OFS then
    result := i
  else
    result := i - USER_ICON_MASKS_OFS + startingImagesCount
end;

function idx_label(i: integer): string;
begin
  result := intToStr(idx_img2ico(i))
end;

function bmp2str(bmp: Tbitmap): string;
var
  stream: Tstringstream;
  gif: TGIFImage;
begin
  { the gif component has a GDI object leak while reducing colors of
    { transparent images. this seems to be not a big problem since the
    { icon cache system was introduced, but a real fix would be nice. }
  stream := Tstringstream.create('');
  gif := TGIFImage.create();

  gif.ColorReduction := rmQuantize;
  gif.Assign(bmp);
  gif.SaveToStream(stream);
  result := stream.DataString;

  gif.free;
  stream.free;
end; // bmp2str

function pic2str(idx: integer): string;
var
  pic, pic2: Tbitmap;
begin
  result := '';
  if idx < 0 then
    exit;
  idx := idx_ico2img(idx);
  if length(imagescache) < idx + 1 then
    setLength(imagescache, idx + 1);
  result := imagescache[idx];
  if result > '' then
    exit;
  pic := Tbitmap.create();
  mainfrm.images.getBitmap(idx, pic);
  // pic2 is the transparent version of pic
  pic2 := Tbitmap.create();
  pic2.Width := mainfrm.images.Width;
  pic2.height := mainfrm.images.height;
  pic2.TransparentMode := tmFixed;

  pic2.TransparentColor := $2FFFFFF;
  pic2.Transparent := TRUE;
  BitBlt(pic2.Canvas.Handle, 0, 0, 16, 16, pic.Canvas.Handle, 0, 0, SRCAND);
  BitBlt(pic2.Canvas.Handle, 0, 0, 16, 16, pic.Canvas.Handle, 0, 0, SRCPAINT);

  result := bmp2str(pic2);
  pic2.free;
  pic.free;
  imagescache[idx] := result;
end; // pic2str

function str2pic(s: string): integer;
var
  gif: TGIFImage;
begin
  for result := 0 to mainfrm.images.count - 1 do
    if pic2str(result) = s then
      exit;
  // in case the pic was not found, it automatically adds it to the pool
  gif := stringToGif(s);
  try
    result := mainfrm.images.addMasked(gif.bitmap, gif.bitmap.TransparentColor);
    etags.values['icon.' + intToStr(result)] := strMD5(s);
  finally
    gif.free
  end;
end; // str2pic

function getImageIndexForFile(fn: string): integer;
var
  i, n: integer;
  ico: Ticon;
  shfi: TShFileInfo;
  s: string;
begin
  fillChar(shfi, SizeOf(TShFileInfo), 0);
  // documentation reports shGetFileInfo() to be working with relative paths too,
  // but it does not actually work without the expandFileName()
  shGetFileInfo(pchar(expandFileName(fn)), 0, shfi, SizeOf(shfi),
    SHGFI_SYSICONINDEX);
  if shfi.iIcon = 0 then
  begin
    result := ICON_FILE;
    exit;
  end;
  // as reported by official docs
  if shfi.hIcon <> 0 then
    destroyIcon(shfi.hIcon);

  // have we already met this sysidx before?
  for i := 0 to length(sysidx2index) - 1 do
    if sysidx2index[i].sysidx = shfi.iIcon then
    begin
      result := sysidx2index[i].idx;
      exit;
    end;
  // found not, let's check deeper: byte comparison.
  // we first add the ico to the list, so we can use pic2str()
  ico := Ticon.create();
  try
    systemimages.getIcon(shfi.iIcon, ico);
    i := mainfrm.images.addIcon(ico);
    s := pic2str(i);
    etags.values['icon.' + intToStr(i)] := strMD5(s);
  finally
    ico.free
  end;
  // now we can search if the icon was already there, by byte comparison
  n := 0;
  while n < length(sysidx2index) do
  begin
    if pic2str(sysidx2index[n].idx) = s then
    begin // found, delete the duplicate
      mainfrm.images.Delete(i);
      setLength(imagescache, i);
      i := sysidx2index[n].idx;
      break;
    end;
    inc(n);
  end;

  n := length(sysidx2index);
  setLength(sysidx2index, n + 1);
  sysidx2index[n].sysidx := shfi.iIcon;
  sysidx2index[n].idx := i;
  result := i;
end; // getImageIndexForFile

function getBaseTrayIcon(perc: real = 0): Tbitmap;
var
  x: integer;
begin
  result := Tbitmap.create();
  result.Width := 16;
  result.height := 16;
  mainfrm.images.getBitmap(if_(assigned(srv) and srv.active, 24, 30), result);
  if perc > 0 then
  begin
    x := round(14 * perc);
    result.Canvas.Brush.color := clYellow;
    result.Canvas.FillRect(rect(1, 7, x + 1, 15));
    result.Canvas.Brush.color := clGreen;
    result.Canvas.FillRect(rect(x + 1, 7, 15, 15));
  end;
end; // getBaseTrayIcon

procedure drawTrayIconString(cnv: Tcanvas; s: string);
var
  x, i, idx: integer;
begin
  x := 10;
  for i := length(s) downto 1 do
  begin
    if s[i] = '%' then
      idx := 10
    else
      idx := ord(s[i]) - ord('0');
    mainfrm.numbers.draw(cnv, x, 8, idx);
    dec(x, mainfrm.numbers.Width);
  end;
end; // drawTrayIconString

procedure repaintTray();
var
  bmp: Tbitmap;
  s: string;
begin
  if quitting or (mainfrm = NIL) then
    exit;
  bmp := getBaseTrayIcon();
  s := trayShows;
  if s = 'connections' then
    s := intToStr(srv.conns.count);
  if s = 'downloads' then
    s := intToStr(downloadsLogged);
  if s = 'uploads' then
    s := intToStr(uploadsLogged);
  if s = 'hits' then
    s := intToStr(hitsLogged);
  if s = 'ips' then
    s := intToStr(countIPs());
  if s = 'ips-ever' then
    s := intToStr(ipsEverConnected.count);

  drawTrayIconString(bmp.Canvas, s);
  tray_ico.Handle := bmpToHico(bmp);
  tray_ico.Transparent := FALSE;
  bmp.free;
  tray.setIcon(tray_ico);
end; // repaintTray

procedure resetTotals();
begin
  hitsLogged := 0;
  downloadsLogged := 0;
  uploadsLogged := 0;
  outTotalOfs := -srv.bytesSent;
  inTotalOfs := -srv.bytesReceived;
  repaintTray();
end; // resetTotals

procedure flash();
begin
  FlashWindow(application.Handle, TRUE);
  if mainfrm.beepChk.checked then
    MessageBeep(MB_OK);
end; // flash

function localDNSget(ip: string): string;
var
  i: integer;
begin
  for i := 0 to length(address2name) div 2 - 1 do
    if addressMatch(address2name[i * 2 + 1], ip) then
    begin
      result := address2name[i * 2];
      exit;
    end;
  result := '';
end; // localDNSget

function existsNodeWithName(name: string; parent: TtreeNode): boolean;
var
  n: TtreeNode;
begin
  result := FALSE;
  if parent = NIL then
    parent := rootNode;
  if parent = NIL then
    exit;
  while assigned(parent.data) and not Tfile(parent.data).isFolder() do
    parent := parent.parent;
  n := parent.getFirstChild();
  while assigned(n) do
  begin
    result := sameText(n.text, name);
    if result then
      exit;
    n := n.getNextSibling();
  end;
end; // existsNodeWithName

function getUniqueNodeName(start: string; parent: TtreeNode): string;
var
  i: integer;
begin
  result := start;
  if not existsNodeWithName(result, parent) then
    exit;
  i := 2;
  repeat
    result := format('%s (%d)', [start, i]);
    inc(i);
  until not existsNodeWithName(result, parent);
end; // getUniqueNodeName

procedure updateDynDNS();

  function interpretResponse(s: string): string;
  const
ERRORS:
  array [1 .. 10] of record code, msg: string;
  end
= ((code: 'badauth'; msg: 'invalid user/password'), (code: 'notfqdn';
  msg: 'incomplete hostname, required form aaa.bbb.com'), (code: 'nohost';
  msg: 'specified hostname does not exist'), (code: '!yours';
  msg: 'specified hostname belongs to another username'), (code: 'numhost';
  msg: 'too many or too few hosts found'), (code: 'abuse';
  msg: 'specified hostname is blocked for update abuse'), (code: 'dnserr';
  msg: 'server error'), (code: '911'; msg: 'server error'), (code: '!donator';
  msg: 'an option specified requires payment'), (code: 'badagent';
  msg: 'banned client'));

var
  i: integer;
  code: string;
begin
  s := trim(s);
  if s = '' then
  begin
    result := 'no reply';
    exit;
  end;
  code := '';
  result := 'successful';
  code := trim(lowercase(getTill(' ', s)));
  if stringExists(code, ['good', 'nochg']) then
    exit;
  for i := 1 to length(ERRORS) do
    if code = ERRORS[i].code then
    begin
      result := 'error: ' + ERRORS[i].msg;
      dyndns.active := FALSE;
      exit;
    end;
  result := 'unknown reply: ' + s;
end; // interpretResponse

var
  s: string;
begin
  if externalIP = '' then
    exit;
  mainfrm.setStatusBarText('Updating dynamic DNS...');
  dyndns.lastTime := now();
  try
    s := httpGet(xtpl(dyndns.url, ['%ip%', externalIP]));
  except
    s := ''
  end;
  if s > '' then
    dyndns.lastResult := s;
  if not mainfrm.logOtherEventsChk.checked then
    exit;
  if length(s) > 30 then
    s := intToStr(length(s)) + ' bytes reply'
  else
    s := interpretResponse(s);
  mainfrm.add2log('DNS update requested for ' + dyndns.lastIP + ': ' + s);
  if dyndns.active then
    dyndns.lastIP := externalIP
  else
    msgDlg('DNS update failed.'#13 + s + '.'#13'User intervention is required.',
      MB_ICONERROR);
  mainfrm.setStatusBarText('');
end; // updateDynDNS

procedure disableUserInteraction();
begin
  if userInteraction.disabled then
    exit;
  userInteraction.disabled := TRUE;
  if mainfrm = NIL then
    userInteraction.bakVisible := FALSE
  else
  begin
    userInteraction.bakVisible := mainfrm.visible;
    mainfrm.visible := FALSE;
  end;
end; // disableUserInteraction

procedure reenableUserInteraction();
begin
  if not userInteraction.disabled then
    exit;
  userInteraction.disabled := FALSE;
  if assigned(mainfrm) then
    mainfrm.visible := userInteraction.bakVisible;
end; // reenableUserInteraction

constructor TconnData.create(conn: ThttpConn);
begin
  conn.data := self;
  self.conn := conn;
  time := now();
  lastActivityTime := time;
  downloadingWhat := DW_UNK;
  urlvars := THashedStringList.create();
  tplCounters := TstringToIntHash.create();
  vars := THashedStringList.create();
  postVars := THashedStringList.create();
end; // constructor

destructor TconnData.destroy;
var
  i: integer;
begin
  for i := 0 to vars.count - 1 do
    if assigned(vars.Objects[i]) and (vars.Objects[i] <> currentCFGhashed) then
    begin
      vars.Objects[i].free;
      vars.Objects[i] := NIL;
    end;
  freeAndNIL(vars);
  freeAndNIL(postVars);
  freeAndNIL(urlvars);
  freeAndNIL(tplCounters);
  freeAndNIL(limiter);
  // do NOT free "tpl". It is just a reference to cached tpl. It will be freed only at quit time.
  if assigned(f) then
  begin
    closeFile(f^);
    freeAndNIL(f);
  end;
  inherited destroy;
end; // destructor

procedure TconnData.disconnect(reason: string);
begin
  disconnectReason := reason;
  conn.disconnect();
end; // disconnect

function TconnData.sessionGet(k: string): string;
begin
  try
    result := session.values[k];
  except
    result := ''
  end;
end; // sessionGet

procedure TconnData.sessionSet(k, v: string);
begin
  if session = NIL then
  begin
    session := THashedStringList.create;
    sessions.addObject(sessionID, session);
  end;
  session.values[k] := v;
end; // sessionSet

// we'll automatically free and previous temporary object
procedure TconnData.setLastFile(f: Tfile);
begin
  freeIfTemp(FlastFile);
  FlastFile := f;
end;

constructor Tfile.create(fullpath: string);
begin
  fullpath := ExcludeTrailingPathDelimiter(fullpath);
  icon := -1;
  size := -1;
  atime := now();
  mtime := atime;
  flags := [];
  setResource(fullpath);
  if (resource > '') and System.SysUtils.DirectoryExists(resource) then
    flags := flags + [FA_FOLDER, FA_BROWSABLE];
end; // create

constructor Tfile.createTemp(fullpath: string);
begin
  create(fullpath);
  include(flags, FA_TEMP);
end; // createTemp

constructor Tfile.createVirtualFolder(name: string);
begin
  icon := -1;
  setResource('');
  flags := [FA_FOLDER, FA_VIRTUAL, FA_BROWSABLE];
  self.name := name;
  atime := now();
  mtime := atime;
end; // createVirtualFolder

constructor Tfile.createLink(name: string);
begin
  icon := -1;
  setName(name);
  atime := now();
  mtime := atime;
  flags := [FA_LINK, FA_VIRTUAL];
end; // createLink

procedure Tfile.setResource(res: string);

  function sameDrive(f1, f2: string): boolean;
  begin
    result := (length(f1) >= 2) and (length(f2) >= 2) and (f1[2] = ':') and
      (f2[2] = ':') and (upcase(f1[1]) = upcase(f2[1]));
  end; // sameDrive

var
  s: string;
begin
  if isExtension(res, '.lnk') or fileExists(res + '\target.lnk') then
  begin
    s := extractFileName(res);
    if isExtension(s, '.lnk') then
      setLength(s, length(s) - 4);
    setName(s);
    lnk := res;
    res := resolveLnk(res);
    include(flags, FA_SOLVED_LNK);
  end
  else
    exclude(flags, FA_SOLVED_LNK);
  res := ExcludeTrailingPathDelimiter(res);

  // in this case, drive letter may change. useful with pendrives.
  if runningOnRemovable and sameDrive(exePath, res) then
    Delete(res, 1, 2);

  resource := res;
  if (length(res) = 2) and (res[2] = ':') then // logical unit
  begin
    include(flags, FA_UNIT);
    if not isRoot() and not(FA_SOLVED_LNK in flags) then
      setName(res);
  end
  else
  begin
    exclude(flags, FA_UNIT);
    if not isRoot() and not(FA_SOLVED_LNK in flags) then
      setName(extractFileName(res));
  end;
  size := -1;
end; // setResource

procedure Tfile.setName(name: string);
begin
  self.name := name;
  if node = NIL then
    exit;
  node.text := name;
end; // setName

function Tfile.same(f: Tfile): boolean;
begin
  result := (self = f) or (resource = f.resource)
end;

function Tfile.toggle(att: TfileAttribute): boolean;
begin
  if att in flags then
    exclude(flags, att)
  else
    include(flags, att);
  result := att in flags
end;

function Tfile.isRoot(): boolean;
begin
  result := FA_ROOT in flags
end;

function Tfile.isFolder(): boolean;
begin
  result := FA_FOLDER in flags
end;

function Tfile.isLink(): boolean;
begin
  result := FA_LINK in flags
end;

function Tfile.isTemp(): boolean;
begin
  result := FA_TEMP in flags
end;

function Tfile.isFile(): boolean;
begin
  result := not((FA_FOLDER in flags) or (FA_LINK in flags))
end;

function Tfile.isFileOrFolder(): boolean;
begin
  result := not(FA_LINK in flags)
end;

function Tfile.isRealFolder(): boolean;
begin
  result := (FA_FOLDER in flags) and not(FA_VIRTUAL in flags)
end;

function Tfile.isVirtualFolder(): boolean;
begin
  result := (FA_FOLDER in flags) and (FA_VIRTUAL in flags)
end;

function Tfile.isEmptyFolder(cd: TconnData = NIL): boolean;
var
  listing: TfileListing;
begin
  result := FALSE;
  if not isFolder() then
    exit;
  listing := TfileListing.create();
  // ** i fear it is not ok to use fromFolder() to know if the folder is empty, because it gives empty also for unallowed folders.
  listing.fromFolder(self, cd, FALSE, 1);
  result := length(listing.dir) = 0;
  listing.free;
end; // isEmptyFolder

// uses comments file
function Tfile.getDynamicComment(skipParent: boolean = FALSE): string;
var
  comments: THashedStringList;
begin
  try
    result := comment;
    if result > '' then
      exit;
    if mainfrm.loadSingleCommentsChk.checked then
      result := loadFile(resource + COMMENT_FILE_EXT);
    if (result > '') or skipParent then
      exit;
    comments := THashedStringList.create();
    try
      try
        comments.caseSensitive := FALSE;
        comments.loadFromFile(resource + '\..\' + COMMENTS_FILE);
        result := comments.values[name];
      except
      end
    finally
      if result = '' then
      begin
        loadIon(resource + '\..', comments);
        result := comments.values[name];
      end;
      if result > '' then
        result := unescapeNL(result);
      comments.free
    end;
  finally
    result := macroQuote(result)
  end;
end; // getDynamicComment

procedure Tfile.setDynamicComment(cmt: string);
var
  s, path, name: string;
  i: integer;
begin
  if not isTemp() then
  begin
    comment := cmt; // quite easy
    exit;
  end;
  path := resource + COMMENT_FILE_EXT;
  if fileExists(path) then
  begin
    if cmt = '' then
      deleteFile(path)
    else
      saveFile(path, cmt);
    exit;
  end;
  name := extractFileName(resource);

  // we prefer descript.ion, but if its support was disabled,
  // or it doesn't exist while hfs.comments.txt does, then we'll use the latter
  path := extractFilePath(resource) + COMMENTS_FILE;
  if not mainfrm.supportDescriptionChk.checked or fileExists(path) and
    not fileExists(extractFilePath(resource) + 'descript.ion') then
    saveFile(path, setKeyInString(loadFile(path), name, escapeNL(cmt)));

  if not mainfrm.supportDescriptionChk.checked then
    exit;

  path := extractFilePath(resource) + 'descript.ion';
  try
    s := loadDescriptionFile(path);
    cmt := escapeIon(cmt); // that's how multilines are handled in this file
    i := findNameInDescriptionFile(s, name);
    if i = 0 then // not found
      if cmt = '' then // no comment, we are good
        exit
      else
        s := s + quoteIfAnyChar(' ', name) + ' ' + cmt + CRLF // append
    else // found, then replace
      if cmt = '' then
        replace(s, '', i, findEOL(s, i)) // remove the whole line
      else
      begin
        i := nonQuotedPos(' ', s, i); // replace just the comment
        replace(s, cmt, i + 1, findEOL(s, i, FALSE));
      end;
    if s = '' then
      deleteFile(path)
    else
      saveFile(path, s);
  except
  end;
end; // setDynamicComment

function Tfile.getParent(): Tfile;
begin
  if node = NIL then
    result := NIL
  else if isTemp() then
    result := nodeToFile(node)
  else if node.parent = NIL then
    result := NIL
  else
    result := node.parent.data
end; // getParent

function Tfile.getDLcount(): integer;
begin
  if isFolder() then
    result := getDLcountRecursive()
  else if isTemp() then
    result := autoupdatedFiles.getInt(resource)
  else
    result := FDLcount;
end; // getDLcount

procedure Tfile.setDLcount(i: integer);
begin
  if isTemp() then
    autoupdatedFiles.setInt(resource, i)
  else
    FDLcount := i;
end; // setDLcount

function Tfile.getDLcountRecursive(): integer;
var
  n: TtreeNode;
  i: integer;
  f: Tfile;
begin
  if not isFolder() then
  begin
    result := DLcount;
    exit;
  end;
  result := 0;
  if node = NIL then
    exit;
  n := node.getFirstChild();
  if not isTemp() then
    while assigned(n) do
    begin
      f := nodeToFile(n);
      if assigned(f) then
        if f.isFolder() then
          inc(result, f.getDLcountRecursive())
        else
          inc(result, f.FDLcount);
      n := n.getNextSibling();
    end;
  if isRealFolder() then
    for i := 0 to autoupdatedFiles.count - 1 do
      if ansiStartsText(resource, autoupdatedFiles[i]) then
        inc(result, autoupdatedFiles.getIntByIdx(i));
end; // getDLcountRecursive

function Tfile.diskfree(): int64;
begin
  if FA_VIRTUAL in flags then
    result := 0
  else
    result := diskSpaceAt(resource);
end; // diskfree

procedure Tfile.setupImage(newIcon: integer);
begin
  icon := newIcon;
  setupImage();
end; // setupImage

procedure Tfile.setupImage();
begin
  if icon >= 0 then
    node.Imageindex := icon
  else
    node.Imageindex := getIconForTreeview();
  node.SelectedIndex := node.Imageindex;
end; // setupImage

function Tfile.getIconForTreeview(): integer;
begin
  if FA_UNIT in flags then
    result := ICON_UNIT
  else if FA_ROOT in flags then
    result := ICON_ROOT
  else if FA_LINK in flags then
    result := ICON_LINK
  else if FA_FOLDER in flags then
    if FA_VIRTUAL in flags then
      result := ICON_FOLDER
    else
      result := ICON_REAL_FOLDER
  else if mainfrm.useSystemIconsChk.checked and (resource > '') then
    result := getImageIndexForFile(resource) // skip iconsCache
  else
    result := ICON_FILE;
end; // getIconForTreeview

function encodeURL(s: string; fullEncode: boolean = FALSE): string;
begin
  if fullEncode or mainfrm.encodenonasciiChk.checked then
    s := ansiToUTF8(s);
  result := Rejetto.HTTPServer.encodeURL(s, mainfrm.encodenonasciiChk.checked,
    fullEncode or mainfrm.encodeSpacesChk.checked)
end; // encodeURL

function protoColon(): string;
const
  LUT: array [boolean] of string = ('http://', 'https://');
begin
  result := LUT[mainfrm.httpsUrlsChk.checked];
end; // protoColon

function totallyEncoded(s: string): string;
var
  i: integer;
begin
  result := '';
  for i := 1 to length(s) do
    result := result + '%' + intToHex(ord(s[i]), 2)
end; // totallyEncoded

function Tfile.relativeURL(fullEncode: boolean = FALSE): string;
begin
  if isLink() then
    result := xtpl(resource, ['%ip%', defaultIP])
  else if isRoot() then
    result := ''
  else
    result := encodeURL(name, fullEncode) + if_(isFolder(), '/')
end;

function Tfile.pathTill(root: Tfile = NIL; delim: char = '\'): string;
var
  f: Tfile;
begin
  result := '';
  if self = root then
    exit;
  result := name;
  f := parent;
  if isTemp() then
  begin
    if FA_SOLVED_LNK in flags then
      result := extractFilePath(copy(lnk, length(f.resource) + 2, MAXINT)) +
        name // the path is the one of the lnk, but we have to replace the file name as the lnk can make it
    else
      result := copy(resource, length(f.resource) + 2, MAXINT);
    if delim <> '\' then
      result := xtpl(result, ['\', delim]);
  end;
  while assigned(f) and (f <> root) and (f <> rootFile) do
  begin
    result := f.name + delim + result;
    f := f.parent;
  end;
end; // pathTill

function Tfile.url(fullEncode: boolean = FALSE): string;
begin
  assert(node <> NIL, 'node can''t be NIL');
  if isLink() then
    result := relativeURL(fullEncode)
  else
    result := '/' + encodeURL(pathTill(rootFile, '/'), fullEncode) +
      if_(isFolder() and not isRoot(), '/');
end; // url

function Tfile.getFolder(): string;
var
  f: Tfile;
  s: string;
begin
  result := '/';
  f := parent;
  while assigned(f) and assigned(f.parent) do
  begin
    result := '/' + f.name + result;
    f := f.parent;
  end;
  if not isTemp() then
    exit;
  f := parent; // f now points to the non-temporary ancestor item
  s := extractFilePath(resource);
  s := copy(s, length(f.resource) + 2, length(s));
  result := result + xtpl(s, ['\', '/']);
end; // getFolder

function Tfile.fullURL(userpwd: string = ''; ip: string = ''): string;
begin
  result := url();
  if isLink() then
    exit;
  if assigned(srv) and srv.active and (srv.port <> '80') and (pos(':', ip) = 0)
    and not mainfrm.noPortInUrlChk.checked then
    result := ':' + srv.port + result;
  if ip = '' then
    ip := defaultIP;
  result := protoColon() + nonEmptyConcat('', userpwd, '@') + ip + result
end; // fullURL

function Tfile.isDLforbidden(): boolean;
var
  f: Tfile;
begin
  // the flag can be in this node
  result := FA_DL_FORBIDDEN in flags;
  if result or not isTemp() then
    exit;
  f := nodeToFile(node);
  result := assigned(f) and (FA_DL_FORBIDDEN in f.flags);
end; // isDLforbidden

function Tfile.isNew(): boolean;
var
  t: Tdatetime;
begin
  if FA_TEMP in flags then
    t := mtime
  else
    t := atime;
  result := (filesStayFlaggedForMinutes > 0) and
    (trunc(abs(now() - t) * 24 * 60) <= filesStayFlaggedForMinutes)
end; // isNew

function Tfile.getRecursiveDiffTplAsStr(outInherited: Pboolean = NIL;
  outFromDisk: Pboolean = NIL): string;
var
  basePath, runPath, s, fn, diff: string;
  f: Tfile;
  first: boolean;

  function add2diff(s: string): boolean;
  begin
    result := FALSE;
    if s = '' then
      exit;
    diff := s + ifThen((diff > '') and not ansiEndsStr(CRLF, s), CRLF) +
      ifThen((diff > '') and not isSectionAt(@diff[1]), '[]' + CRLF) + diff;
    result := TRUE;
  end; // add2diff

begin
  result := '';
  diff := '';
  runPath := '';
  f := self;
  if assigned(outInherited) then
    outInherited^ := FALSE;
  if assigned(outFromDisk) then
    outFromDisk^ := FALSE;
  first := TRUE;
  while assigned(f) do
  begin
    if f.isRealFolder() then
      if f.isTemp() then
      begin
        basePath := ExcludeTrailingPathDelimiter
          (extractFilePath(f.parent.resource));
        runPath := copy(f.resource, length(basePath) + 2, length(f.resource));
        f := f.parent;
      end
      else
      begin
        basePath := ExcludeTrailingPathDelimiter(extractFilePath(f.resource));
        runPath := extractFileName(f.resource);
      end;
    // temp realFolder will cycle more than once, while non-temp only once
    while runPath > '' do
    begin
      if add2diff(loadFile(basePath + '\' + runPath + '\' + DIFF_TPL_FILE)) and
        assigned(outFromDisk) then
        outFromDisk^ := TRUE;
      runPath := ExcludeTrailingPathDelimiter(extractFilePath(runPath));
    end;
    // consider the diffTpl in node
    s := f.diffTpl;
    if (s > '') and singleLine(s) then
    begin
      // maybe it refers to a file
      fn := trim(s);
      if fileExists(fn) then
        doNothing()
      else if fileExists(exePath + fn) then
        fn := exePath + fn
      else if fileExists(f.resource + '\' + fn) then
        fn := f.resource + '\' + fn;
      if fileExists(fn) then
        s := loadFile(fn);
    end;
    if add2diff(s) and not first and assigned(outInherited) then
      outInherited^ := TRUE;
    f := f.parent;
    first := FALSE;
  end;
  result := diff;
end; // getRecursiveDiffTplAsStr

function Tfile.getDefaultFile(): Tfile;
var
  f: Tfile;
  mask, s: string;
  sr: TSearchRec;
  n: TtreeNode;
begin
  result := NIL;
  mask := getRecursiveFileMask();
  if mask = '' then
    exit;

  n := node.getFirstChild();
  { if this folder has been dinamically generated, the treenode is not actually
    { its own, and we won't care about subitems }
  if not isTemp() then
    while assigned(n) do
    begin
      f := n.data;
      n := n.getNextSibling();
      if (FA_LINK in f.flags) or f.isFolder() or not fileMatch(mask, f.name) or
        not fileExists(f.resource) then
        continue;
      result := f;
      exit;
    end;

  if not isRealFolder() or not System.SysUtils.DirectoryExists(resource) then
    exit;

  while mask > '' do
  begin
    s := chop(';', mask);
    if findfirst(resource + '\' + s, faAnyFile - faDirectory, sr) <> 0 then
      continue;
    try
      // encapsulate for returning
      result := Tfile.createTemp(resource + '\' + sr.name);
      result.node := node; // temporary nodes are bound to the parent's node
    finally
      findClose(sr)
    end;
    exit;
  end;
end; // getDefaultFile

function Tfile.shouldCountAsDownload(): boolean;
var
  f: Tfile;
  mask: string;
begin
  result := not(FA_DONT_COUNT_AS_DL in flags);
  if not result then
    exit;
  f := self;
  repeat
    mask := f.dontCountAsDownloadMask;
    f := f.parent;
  until (f = NIL) or (mask > '');
  if mask > '' then
    result := not fileMatch(mask, name)
end; // shouldCountAsDownload

function Tfile.getShownRealm(): string;
var
  f: Tfile;
begin
  f := self;
  repeat
    result := f.realm;
    if result > '' then
      exit;
    f := f.parent;
  until f = NIL;
  if mainfrm.useCommentAsRealmChk.checked then
    result := getDynamicComment();
end; // getShownRealm

function Tfile.parentURL(): string;
var
  i: integer;
begin
  result := url(TRUE);
  i := length(result) - 1;
  while (i > 1) and (result[i] <> '/') do
    dec(i);
  setLength(result, i);
end; // parentURL

function Tfile.getSystemIcon(): integer;
var
  ic: PcachedIcon;
  i: integer;
begin
  result := icon;
  if result >= 0 then
    exit;
  if isFile() then
    for i := 0 to length(iconMasks) - 1 do
      if fileMatch(iconMasks[i].str, name) then
      begin
        result := iconMasks[i].int;
        exit;
      end;
  ic := iconsCache.get(resource);
  if ic = NIL then
  begin
    result := getImageIndexForFile(resource);
    iconsCache.put(resource, result, mtime);
    exit;
  end;
  if mtime <= ic.time then
    result := ic.idx
  else
  begin
    result := getImageIndexForFile(resource);
    ic.time := mtime;
    ic.idx := result;
  end;
end; // getSystemIcon

procedure Tfile.lock();
begin
  locked := TRUE
end;

procedure Tfile.unlock();
begin
  locked := FALSE
end;

function Tfile.isLocked(): boolean;
var
  f: Tfile;
  n: TtreeNode;
begin
  // check ancestors (first, because it is always fast)
  f := self;
  repeat
    result := f.locked;
    f := f.parent;
  until (f = NIL) or result;
  // check descendants
  n := node.getFirstChild();
  while assigned(n) and not result do
  begin
    result := nodeToFile(n).isLocked();
    n := n.getNextSibling();
  end;
end; // isLocked

procedure Tfile.recursiveApply(callback: TfileCallback; par: integer = 0;
  par2: integer = 0);
var
  n, next: TtreeNode;
  r: TfileCallbackReturn;
begin
  r := callback(self, FALSE, par, par2);
  if FCB_DELETE in r then
  begin
    node.Delete();
    exit;
  end;
  if FCB_NO_DEEPER in r then
    exit;
  n := node.getFirstChild();
  while assigned(n) do
  begin
    next := n.getNextSibling();
    // "next" must be saved this point because the callback may delete the current node
    if assigned(n.data) then
      nodeToFile(n).recursiveApply(callback, par, par2);
    n := next;
  end;
  if FCB_RECALL_AFTER_CHILDREN in r then
  begin
    r := callback(self, TRUE, par, par2);
    if FCB_DELETE in r then
      node.Delete();
  end;
end; // recursiveApply

function Tfile.hasRecursive(attributes: TfileAttributes;
  orInsteadOfAnd: boolean = FALSE; outInherited: Pboolean = NIL): boolean;
var
  f: Tfile;
begin
  result := FALSE;
  f := self;
  if assigned(outInherited) then
    outInherited^ := FALSE;
  while assigned(f) do
  begin
    result := orInsteadOfAnd and (attributes * f.flags <> []) or
      (attributes * f.flags = attributes);
    if result then
      exit;
    f := f.parent;
    if assigned(outInherited) then
      outInherited^ := TRUE;
  end;
  if assigned(outInherited) then
    outInherited^ := FALSE; // grant it is set only if result=TRUE
end; // hasRecursive

function Tfile.hasRecursive(attribute: TfileAttribute;
  outInherited: Pboolean = NIL): boolean;
begin
  result := hasRecursive([attribute], FALSE, outInherited)
end;

function Tfile.accessFor(cd: TconnData): boolean;
begin
  if cd = NIL then
    result := accessFor('', '')
  else
    result := accessFor(cd.usr, cd.pwd)
end; // accessFor

function Tfile.accessFor(username, password: string): boolean;
var
  a: Paccount;
  f: Tfile;
  list: TStringDynArray;
begin
  result := FALSE;
  if isFile() and isDLforbidden() then
    exit;
  result := FALSE;
  f := self;
  while assigned(f) do
  begin
    list := f.accounts[FA_ACCESS]; // shortcut

    if (username = '') and stringExists(USER_ANONYMOUS, list, TRUE) then
      break;
    // first check in user/pass
    if (f.user > '') and sameText(f.user, username) and (f.pwd = password) then
      break;
    // then in accounts
    if assigned(list) then
    begin
      a := getAccount(username);

      if stringExists(USER_ANYONE, list, TRUE) then
        break;
      // we didn't match the user/pass, but this file is restricted, so we must have an account at least to access it
      if assigned(a) and (a.pwd = password) and
        (stringExists(USER_ANY_ACCOUNT, list, TRUE) or
        (findEnabledLinkedAccount(a, list, TRUE) <> NIL)) then
        break;

      exit;
    end;
    // there's a user/pass restriction, but the password didn't match (if we got this far). We didn't exit before to give accounts a chance.
    if f.user > '' then
      exit;

    f := f.parent;
  end;
  result := TRUE;

  // in case the file is not protected, we must not accept authentication credentials belonging to disabled accounts
  if (username > '') and (f = NIL) then
  begin
    a := getAccount(username);
    if a = NIL then
      exit;
    result := a.enabled;
  end;
end; // accessFor

function Tfile.getRecursiveFileMask(): string;
var
  f: Tfile;
begin
  f := self;
  repeat
    result := f.defaultFileMask;
    if result > '' then
      exit;
    f := f.parent;
  until f = NIL;
end; // getRecursiveFileMask

function Tfile.getAccountsFor(action: TfileAction;
  specialUsernames: boolean = FALSE; outInherited: Pboolean = NIL)
  : TStringDynArray;
var
  i: integer;
  f: Tfile;
  s: string;
begin
  result := NIL;
  f := self;
  if assigned(outInherited) then
    outInherited^ := FALSE;
  while assigned(f) do
  begin
    for i := 0 to length(f.accounts[action]) - 1 do
    begin
      s := f.accounts[action][i];
      if (s = '') or (action = FA_UPLOAD) and not f.isRealFolder() then
        continue; // we must ignore this setting

      if specialUsernames and (s[1] = '@') or accountExists(s, specialUsernames)
      then // we admit groups only if specialUsernames are admitted too
        addString(s, result);
    end;
    if (action = FA_ACCESS) and (f.user > '') then
      addString(f.user, result);
    if assigned(result) then
      exit;
    if assigned(outInherited) then
      outInherited^ := TRUE;
    f := f.parent;
  end;
end; // getAccountsFor

procedure Tfile.getFiltersRecursively(var files, folders: string);
var
  f: Tfile;
begin
  files := '';
  folders := '';
  f := self;
  while assigned(f) do
  begin
    if (files = '') and (f.filesFilter > '') then
      files := f.filesFilter;
    if (folders = '') and (f.foldersFilter > '') then
      folders := f.foldersFilter;
    if (files > '') and (folders > '') then
      break;
    f := f.parent;
  end;
end; // getFiltersRecursively

procedure kickByIP(ip: string);
var
  i: integer;
  d: TconnData;
begin
  i := 0;
  while i < srv.conns.count do
  begin
    d := conn2data(i);
    if assigned(d) and (d.address = ip) or (ip = '*') then
      d.disconnect(first(d.disconnectReason, 'kicked'));
    inc(i);
  end;
end; // kickByIP

function getSafeHost(cd: TconnData): string;
begin
  result := '';
  if cd = NIL then
    exit;
  if addressMatch(forwardedMask, cd.conn.address) then
    result := cd.conn.getHeader('x-forwarded-host');
  if result = '' then
    result := cd.conn.getHeader('host');
  result := stripChars(result, ['0' .. '9', 'a' .. 'z', 'A' .. 'Z', ':', '.',
    '-', '_'], TRUE);
end; // getSafeHost

function nodeIsLocked(n: TtreeNode): boolean;
begin
  result := FALSE;
  if (n = NIL) or (n.data = NIL) then
    exit;
  result := nodeToFile(n).isLocked();
end; // nodeIsLocked

function objByIP(ip: string): TperIp;
var
  i: integer;
begin
  i := ip2obj.indexOf(ip);
  if i < 0 then
    i := ip2obj.add(ip);
  if ip2obj.Objects[i] = NIL then
    ip2obj.Objects[i] := TperIp.create();
  result := ip2obj.Objects[i] as TperIp;
end; // objByIP

function Tmainfrm.findFilebyURL(url: string; parent: Tfile = NIL;
  allowTemp: boolean = TRUE): Tfile;

  procedure workTheRestByReal(rest: string; f: Tfile);
  var
    s: string;
  begin
    if not allowTemp then
      exit;

    s := rest; // just a shortcut
    if dirCrossing(s) then
      exit;

    s := includeTrailingPathDelimiter(f.resource) + s;
    // we made the ".." test before, so relative paths are allowed in the VFS
    if not fileOrDirExists(s) then
      if fileOrDirExists(s + '.lnk') then
        s := s + '.lnk'
      else
        s := UTF8ToAnsi(s);
    // these may actually be two distinct files, but it's very unlikely to be, and pratically we workaround big problem
    if not fileOrDirExists(s) or not hasRightAttributes(s) then
      exit;
    // found on disk, we need to build a temporary Tfile to return it
    result := Tfile.createTemp(s);
    // the temp file inherits flags from the real folder
    if FA_DONT_LOG in f.flags then
      include(result.flags, FA_DONT_LOG);
    if not(FA_BROWSABLE in f.flags) then
      exclude(result.flags, FA_BROWSABLE);
    // temp nodes are bound to parent's node
    result.node := f.node;
  end; // workTheRestByReal

var
  parts: TStringDynArray;
  s: string;
  cur, n: TtreeNode;
  found: boolean;
  f: Tfile;
  i, j: integer;

  function workDots(): boolean;
  label REMOVE;
  var
    i: integer;
  begin
    result := FALSE;
    i := 0;
    while i < length(parts) do
    begin
      if parts[i] = '.' then
        goto REMOVE;
      // 10+ years have passed since the last time i used labels in pascal. It's a thrill.
      if parts[i] <> '..' then
      begin
        inc(i);
        continue;
      end;
      if i > 0 then
      begin
        removeString(parts, i - 1, 2);
        dec(i);
        continue;
      end;
      parent := parent.parent;
      if parent = NIL then
        exit;
    REMOVE:
      removeString(parts, i, 1);
    end;
    result := TRUE;
  end; // workDots

begin
  result := NIL;
  if (url = '') or anycharIn(#0, url) then
    exit;
  if parent = NIL then
    parent := rootFile;
  url := xtpl(url, ['//', '/']);
  if url[1] = '/' then
  begin
    Delete(url, 1, 1); // remove initial "/"
    parent := rootFile; // it's an absolute path, not relative
  end;
  excludeTrailingString(url, '/');
  parts := split('/', url);
  if not workDots() then
    exit;

  if parent.isTemp() then
  begin
    workTheRestByReal(url, parent);
    exit;
  end;

  cur := parent.node; // we'll move using treenodes
  for i := 0 to length(parts) - 1 do
  begin
    s := parts[i];
    if s = '' then
      exit; // no support for null filenames
    found := FALSE;
    // search inside the VFS
    n := cur.getFirstChild();
    while assigned(n) do
    begin
      found := stringExists(n.text, s) or sameText(n.text, UTF8ToAnsi(s));
      if found then
        break;
      n := n.getNextSibling();
    end;
    if not found then // this piece was not found the virtual way
    begin
      f := cur.data;
      if f.isRealFolder() then
      // but real folders have not all the stuff loaded and ready. we have another way to walk.
      begin
        for j := i + 1 to length(parts) - 1 do
          s := s + '\' + parts[j];
        workTheRestByReal(s, f);
      end;
      exit;
    end;
    cur := n;
    if cur = NIL then
      exit;
  end;
  result := cur.data;
end; // findFileByURL

function fileExistsByURL(url: string): boolean;
var
  f: Tfile;
begin
  f := mainfrm.findFilebyURL(url);
  result := assigned(f);
  freeIfTemp(f);
end; // fileExistsByURL

function getAccountList(users: boolean = TRUE; groups: boolean = TRUE)
  : TStringDynArray;
var
  i, n: integer;
begin
  setLength(result, length(accounts));
  n := 0;
  for i := 0 to length(result) - 1 do
    with accounts[i] do
      if group and groups or not group and users then
      begin
        result[n] := user;
        inc(n);
      end;
  setLength(result, n);
end; // getAccountList

function banAddress(ip: string): boolean;
const
  msg = 'There are %d open connections from this address.'#13 +
    'Do you want to kick them all now?';
  MSG2 = 'You can edit the address.'#13'Masks and ranges are allowed.';
var
  i: integer;
  comm: string;
begin
  result := FALSE;
  mainfrm.setFocus();
  if not InputQuery('IP mask', MSG2, ip) then
    exit;

  for i := 0 to length(banlist) - 1 do
    if banlist[i].ip = ip then
    begin
      msgDlg('This IP address is already banned', MB_ICONWARNING);
      exit;
    end;

  comm := '';
  if not InputQuery('Ban comment', 'A comment for this ban...', comm) then
    exit;

  i := length(banlist);
  setLength(banlist, i + 1);
  banlist[i].ip := ip;
  banlist[i].comment := comm;

  i := countConnectionsByIP(ip);
  if (i > 0) and (msgDlg(format(msg, [i]), MB_ICONQUESTION + MB_YESNO) = IDYES)
  then
    kickByIP(ip);
  result := TRUE;
end; // banAddress

function createFingerprint(fn: string): string;
var
  fs: Tfilestream;
  digest: TMD5Digest;
  context: TMD5Context;
  buf: array [1 .. 32 * 1024] of byte;
  i: integer;
begin
  result := '';
  fs := Tfilestream.create(fn, fmOpenRead + fmShareDenyWrite);
  for i := 0 to 15 do
    byte(digest[i]) := succ(i);
  MD5init(context);
  try
    repeat
      i := fs.Read(buf, SizeOf(buf));
      MD5updateBuffer(context, @buf, i);
      if not progFrm.visible then
        continue;
      progFrm.progress := safeDiv(0.0 + fs.position, fs.size);
      application.ProcessMessages();
      if progFrm.cancelRequested then
        exit;
    until i < SizeOf(buf);
  finally
    fs.free;
    MD5final(digest, context);
    for i := 0 to 15 do
      result := result + intToHex(byte(digest[i]), 2);
  end;
end; // createFingerprint

function uptimestr(): string;
var
  t: Tdatetime;
begin
  result := 'server down';
  if not srv.active then
    exit;
  t := now() - uptime;
  result := if_(t > 1, format('(%d days) ', [trunc(t)])) +
    formatDateTime('hh:nn:ss', t)
end; // uptimeStr

function loadMD5for(fn: string): string;
begin
  if getMtimeUTC(fn + '.md5') < getMtimeUTC(fn) then
    result := ''
  else
    result := trim(getTill(' ', loadFile(fn + '.md5')))
end; // loadMD5for

function shouldRecur(data: TconnData): boolean;
begin
  result := mainfrm.recursiveListingChk.checked and
    ((data.urlvars.indexOf('recursive') >= 0) or
    (data.urlvars.values['search'] > ''))
end; // shouldRecur

function Tmainfrm.getFolderPage(folder: Tfile; cd: TconnData;
  otpl: Tobject): string;
// we pass the Tpl parameter as Tobject because symbol Ttpl is not defined yet

var
  baseurl, list, fileTpl, folderTpl, linkTpl: string;
  table: TStringDynArray;
  ofsRelItemUrl, ofsRelUrl, numberFiles, numberFolders, numberLinks: integer;
  img_file: boolean;
  totalBytes: int64;
  fast: TfastStringAppend;
  buildTime: Tdatetime;
  listing: TfileListing;
  diffTpl: TTemplate;
  isDMbrowser: boolean;
  hasher: Thasher;
  fullEncode, recur, oneAccessible: boolean;
  md: TmacroData;

  procedure applySequential();
  const
    PATTERN = '%sequential%';
  var
    idx, p: integer;
    idxS: string;
  begin
    idx := 0;
    p := 1;
    repeat
      p := ipos(PATTERN, result, p);
      if p = 0 then
        exit;
      inc(idx);
      idxS := intToStr(idx);
      Delete(result, p, length(PATTERN) - length(idxS));
      move(idxS[1], result[p], length(idxS));
    until FALSE;
  end; // applySequential

  procedure handleItem(f: Tfile);
  var
    type_, s, url, fingerprint, itemFolder: string;
    nonPerc: TStringDynArray;
  begin
    if not f.isLink and ansiContainsStr(f.resource, '?') then
      exit; // unicode filename?   //mod by mars

    if f.size > 0 then
      inc(totalBytes, f.size);

    // build up the symbols table
    md.table := NIL;
    nonPerc := NIL;
    if f.icon >= 0 then
    begin
      s := '~img' + intToStr(f.icon);
      addArray(nonPerc, ['~img_folder', s, '~img_link', s]);
    end;
    if f.isFile() then
      if img_file and (useSystemIconsChk.checked or (f.icon >= 0)) then
        addArray(nonPerc, ['~img_file', '~img' + intToStr(f.getSystemIcon())]);

    if recur or (itemFolder = '') then
      itemFolder := optUTF8(diffTpl, f.getFolder());
    if recur then
      url := substr(itemFolder, ofsRelItemUrl)
    else
      url := '';
    addArray(md.table, ['%item-folder%', itemFolder,
      '%item-relative-folder%', url]);

    if not f.accessFor(cd) then
      s := diffTpl['protected']
    else
    begin
      s := '';
      if f.isFileOrFolder() then
        oneAccessible := TRUE;
    end;
    addArray(md.table, ['%protected%', s]);

    // url building
    fingerprint := '';
    if fingerprintsChk.checked and f.isFile() then
    begin
      s := loadMD5for(f.resource);
      if s = '' then
        s := hasher.getHashFor(f.resource);
      if s > '' then
        fingerprint := '#!md5!' + s;
    end;
    if f.isLink() then
    begin
      url := f.resource;
      s := url;
    end
    else if pwdInPagesChk.checked and (cd.usr > '') then
    begin
      if encodePwdUrlChk.checked then
        s := totallyEncoded(cd.pwd)
      else
        s := encodeURL(cd.pwd);
      s := f.fullURL(encodeURL(cd.usr) + ':' + s, getSafeHost(cd)) +
        fingerprint;
      url := s
    end
    else
    begin
      if recur then
        s := copy(f.url(fullEncode), ofsRelUrl, MAXINT) + fingerprint
      else
        s := f.relativeURL(fullEncode) + fingerprint;
      url := baseurl + s;
    end;

    if not f.isLink() then
    begin
      s := macroQuote(s);
      url := macroQuote(url);
    end;

    addArray(md.table, ['%item-url%', s, '%item-full-url%', url]);

    // select appropriate template
    if f.isLink() then
    begin
      s := linkTpl;
      inc(numberLinks);
      type_ := 'link';
    end
    else if f.isFolder() then
    begin
      s := folderTpl;
      inc(numberFolders);
      type_ := 'folder';
    end
    else
    begin
      s := diffTpl.getTxtByExt(ExtractFileExt(f.name));
      if s = '' then
        s := fileTpl;
      inc(numberFiles);
      type_ := 'file';
    end;

    addArray(md.table, ['%item-type%', type_]);

    s := xtpl(s, nonPerc);
    md.f := f;
    tryApplyMacrosAndSymbols(s, md, FALSE);
    fast.append(s);
  end; // handleItem

var
  i: integer;
begin
  result := '';
  if (folder = NIL) or not folder.isFolder() then
    exit;

  if macrosLogChk.checked and not appendmacroslog1.checked then
    resetLog();
  diffTpl := TTemplate.create();
  folder.lock();
  try
    buildTime := now();
    cd.conn.addHeader
      ('Cache-Control: no-cache, no-store, must-revalidate, max-age=-1');
    recur := shouldRecur(cd);
    baseurl := protoColon() + getSafeHost(cd) + folder.url(TRUE);

    if cd.tpl = NIL then
      diffTpl.over := otpl as TTemplate
    else
    begin
      diffTpl.over := cd.tpl;
      cd.tpl.over := otpl as TTemplate;
    end;

    if otpl <> filelistTpl then
      diffTpl.fullText := optUTF8(diffTpl.over,
        folder.getRecursiveDiffTplAsStr());

    isDMbrowser := otpl = dmBrowserTpl;
    fullEncode := not isDMbrowser;
    ofsRelUrl := length(folder.url(fullEncode)) + 1;
    ofsRelItemUrl := length(optUTF8(diffTpl, folder.pathTill())) + 1;
    // pathTill() is '/' for root, and 'just/folder', so we must accordingly consider a starting and trailing '/' for the latter case (bugfix by mars)
    if not folder.isRoot() then
      inc(ofsRelItemUrl, 2);

    fillChar(md, SizeOf(md), 0);
    md.cd := cd;
    md.tpl := diffTpl;
    md.folder := folder;
    md.archiveAvailable := folder.hasRecursive(FA_ARCHIVABLE) and
      not folder.isDLforbidden();
    md.hideExt := folder.hasRecursive(FA_HIDE_EXT);

    result := diffTpl['special:begin'];
    tryApplyMacrosAndSymbols(result, md, FALSE);

    // cache these values
    fileTpl := xtpl(diffTpl['file'], table);
    folderTpl := xtpl(diffTpl['folder'], table);
    linkTpl := xtpl(diffTpl['link'], table);
    // this may be heavy to calculate, only do it upon request
    img_file := pos('~img_file', fileTpl) > 0;

    // build %list% based on dir[]
    numberFolders := 0;
    numberFiles := 0;
    numberLinks := 0;
    totalBytes := 0;
    oneAccessible := FALSE;
    fast := TfastStringAppend.create();
    listing := TfileListing.create();
    hasher := Thasher.create();
    if fingerprintsChk.checked then
      hasher.loadFrom(folder.resource);
    try
      listing.fromFolder(folder, cd, recur);
      listing.sort(cd, if_(recur or (otpl = filelistTpl), '?',
        diffTpl['sort by']));
      // '?' is just a way to cause the sort to fail in case the sort key is not defined by the connection

      for i := 0 to length(listing.dir) - 1 do
      begin
        application.ProcessMessages();
        if cd.conn.state = HCS_DISCONNECTED then
          exit;
        cd.lastActivityTime := now();
        handleItem(listing.dir[i])
      end;
      list := fast.reset();
    finally
      listing.free;
      fast.free;
      hasher.free;
    end;

    if cd.conn.state = HCS_DISCONNECTED then
      exit;

    // build final page
    if not oneAccessible then
      md.archiveAvailable := FALSE;
    md.table := toSA(['%upload-link%', if_(accountAllowed(FA_UPLOAD, cd,
      folder), diffTpl['upload-link']), '%files%',
      if_(list = '', diffTpl['nofiles'], diffTpl['files']), '%list%', list,
      '%number%', intToStr(numberFiles + numberFolders + numberLinks),
      '%number-files%', intToStr(numberFiles), '%number-folders%',
      intToStr(numberFolders), '%number-links%', intToStr(numberLinks),
      '%total-bytes%', intToStr(totalBytes), '%total-kbytes%',
      intToStr(totalBytes div KILO), '%total-size%', smartsize(totalBytes)]);
    result := diffTpl[''];
    md.f := NIL;
    md.afterTheList := TRUE;
    try
      tryApplyMacrosAndSymbols(result, md)
    finally
      md.afterTheList := FALSE
    end;
    applySequential();
    // ensure this is the last symbol to be translated
    result := xtpl(result, ['%build-time%',
      floatToStrF((now() - buildTime) * SECONDS, ffFixed, 7, 3)]);
  finally
    folder.unlock();
    diffTpl.free;
  end;
end; // getFolderPage

function getETA(data: TconnData): string;
begin
  if (data.conn.state in [HCS_REPLYING_BODY, HCS_POSTING]) and
    (data.eta.idx > ETA_FRAME) then
    result := elapsedToStr(data.eta.result)
  else
    result := '-'
end; // getETA

function tplFromFile(f: Tfile): TTemplate;
begin
  result := TTemplate.create(optUTF8(Template, f.getRecursiveDiffTplAsStr()), Template)
end;

procedure setDefaultIP(v: string);
var
  old: string;
begin
  old := defaultIP;
  if v > '' then
    defaultIP := v
  else if externalIP > '' then
    defaultIP := externalIP
  else
    defaultIP := getIP();
  if mainfrm = NIL then
    exit;
  mainfrm.updateUrlBox();
  if old = defaultIP then
    exit;
  try
    v := clipboard.AsText;
    if pos(old, v) = 0 then
      exit;
  except
  end;
  setClip(xtpl(v, [old, defaultIP]));
end; // setDefaultIP

function name2mimetype(fn: string; default: string): string;
var
  i: integer;
begin
  result := default;
  for i := 0 to length(mimeTypes) div 2 - 1 do
    if fileMatch(mimeTypes[i * 2], fn) then
    begin
      result := mimeTypes[i * 2 + 1];
      exit;
    end;
  for i := 0 to length(DEFAULT_MIME_TYPES) div 2 - 1 do
    if fileMatch(DEFAULT_MIME_TYPES[i * 2], fn) then
    begin
      result := DEFAULT_MIME_TYPES[i * 2 + 1];
      exit;
    end;
end; // name2mimetype

procedure Tmainfrm.getPage(sectionName: string; data: TconnData; f: Tfile = NIL;
  tpl2use: TTemplate = NIL);
var
  md: TmacroData;

  procedure addProgressSymbols();
  var
    t, files, fn: string;
    i: integer;
    d: TconnData;
    perc: real;
    bytes, total: int64;
  begin
    if sectionName <> 'progress' then
      exit;

    bytes := 0;
    total := 0; // shut up compiler
    files := '';
    i := -1;
    repeat // a while-loop would look better but would lead to heavy indentation
      inc(i);
      if i >= srv.conns.count then
        break;
      d := conn2data(i);
      if d.address <> data.address then
        continue;
      fn := '';
      // fill fields
      if isReceivingFile(d) then
      begin
        t := tpl2use['progress-upload-file'];
        fn := d.uploadSrc; // already encoded by the browser
        bytes := d.conn.bytesPosted;
        total := d.conn.post.length;
      end;
      if isSendingFile(d) then
      begin
        if d.conn.reply.bodyMode <> RBM_FILE then
          continue;
        t := tpl2use['progress-download-file'];
        fn := optUTF8(tpl2use, d.lastFN);
        bytes := d.conn.bytesSentLastItem;
        total := d.conn.bytesPartial;
      end;
      perc := safeDiv(0.0 + bytes, total);
      // 0.0 forces a typecast that will call the right overloaded function
      // no file exchange
      if fn = '' then
        continue;
      fn := macroQuote(fn);
      // apply fields
      files := files + xtpl(t, ['%item-user%', macroQuote(d.usr), '%perc%',
        intToStr(trunc(perc * 100)), '%filename%', fn, '%filename-js%',
        jsEncode(fn, '''"'), '%done-bytes%', intToStr(bytes), '%total-bytes%',
        intToStr(total), '%done%', smartsize(bytes), '%total%',
        smartsize(total), '%time-left%', getETA(d), '%speed-kb%',
        floatToStrF(d.averageSpeed / 1000, ffFixed, 7, 1), '%item-ip%',
        d.address, '%item-port%', d.conn.port]);
    until FALSE;
    if files = '' then
      files := tpl2use['progress-nofiles'];
    addArray(md.table, ['%progress-files%', files]);
  end; // addProgressSymbols

  procedure addUploadSymbols();
  var
    i: integer;
    files: string;
  begin
    if sectionName <> 'upload' then
      exit;
    files := '';
    for i := 1 to 10 do
      files := files + xtpl(tpl2use['upload-file'], ['%idx%', intToStr(i)]);
    addArray(md.table, ['%upload-files%', files]);
  end; // addUploadSymbols

  procedure addUploadResultsSymbols();
  var
    files: string;
    i: integer;
  begin
    if sectionName <> 'upload-results' then
      exit;
    files := '';
    for i := 0 to length(data.uploadResults) - 1 do
      with data.uploadResults[i] do
        files := files + xtpl(tpl2use[if_(reason = '', 'upload-success',
          'upload-failed')], ['%item-name%',
          htmlEncode(macroQuote(optUTF8(tpl2use, fn))), '%item-url%',
          macroQuote(encodeURL(fn)), '%item-size%', smartsize(size),
          '%item-resource%', f.resource + '\' + fn, '%idx%', intToStr(i + 1),
          '%reason%', optUTF8(tpl2use, reason), '%speed%',
          intToStr(speed div 1000), // legacy
          '%smart-speed%', smartsize(speed)]);
    addArray(md.table, ['%uploaded-files%', files]);
  end; // addUploadResultsSymbols

var
  s: string;
  section: PTemplateSection;
  buildTime: Tdatetime;
  externalTpl: boolean;
begin
  buildTime := now();

  externalTpl := assigned(tpl2use);
  if not externalTpl then
    tpl2use := tplFromFile(Tfile(first(f, rootFile)));
  if assigned(data.tpl) then
  begin
    data.tpl.over := tpl2use.over;
    tpl2use.over := data.tpl;
  end;

  try
    data.conn.reply.mode := HRM_REPLY;
    data.conn.reply.bodyMode := RBM_STRING;
    data.conn.reply.body := '';
  except
  end;

  section := tpl2use.getSection(sectionName);
  if section = NIL then
    exit;

  try
    fillChar(md, SizeOf(md), 0);
    addUploadSymbols();
    addProgressSymbols();
    addUploadResultsSymbols();
    if data = NIL then
      s := ''
    else
      s := first(data.banReason, data.disconnectReason);
    addArray(md.table, ['%reason%', optUTF8(tpl2use, s)]);

    data.conn.reply.contentType := name2mimetype(sectionName, 'text/html');
    if sectionName = 'ban' then
      data.conn.reply.mode := HRM_DENY;
    if sectionName = 'deny' then
      data.conn.reply.mode := HRM_DENY;
    if sectionName = 'not found' then
      data.conn.reply.mode := HRM_NOT_FOUND;
    if sectionName = 'unauthorized' then
      data.conn.reply.mode := HRM_UNAUTHORIZED;
    if sectionName = 'overload' then
      data.conn.reply.mode := HRM_OVERLOAD;
    if sectionName = 'max contemp downloads' then
      data.conn.reply.mode := HRM_OVERLOAD;

    md.cd := data;
    md.tpl := tpl2use;
    md.folder := f;
    md.f := NIL;
    md.archiveAvailable := FALSE;
    s := tpl2use['special:begin'];
    tryApplyMacrosAndSymbols(s, md, FALSE);

    if data.conn.reply.mode = HRM_REPLY then
      s := section.txt
    else
    begin
      s := xtpl(tpl2use['error-page'], ['%content%', section.txt]);
      if s = '' then
        s := section.txt;
    end;

    tryApplyMacrosAndSymbols(s, md);

    data.conn.reply.body :=
      xtpl(s, ['%build-time%', floatToStrF((now() - buildTime) * SECONDS,
      ffFixed, 7, 3)]);
    if section.nolog then
      data.dontLog := TRUE;
    compressReply(data);
  finally
    if not externalTpl then
      tpl2use.free
  end
end; // getPage

procedure Tmainfrm.findExtOnStartupChkClick(Sender: Tobject);
const
  msg = 'This option is NOT compatible with "dynamic dns updater".' +
    #13'Continue?';
begin
  with Sender as TMenuItem do
    if dyndns.active and (dyndns.url > '') and checked then
      checked := msgDlg(msg, MB_ICONWARNING + MB_YESNO) = MRYES;
end;

function notModified(conn: ThttpConn; etag, ts: string): boolean; overload;
begin
  result := (etag > '') and (etag = conn.getHeader('If-None-Match'));
  if result then
  begin
    conn.reply.mode := HRM_NOT_MODIFIED;
    exit;
  end;
  conn.addHeader('ETag: ' + etag);
  if ts > '' then
    conn.addHeader('Last-Modified: ' + ts);
end; // notModified

function notModified(conn: ThttpConn; f: string): boolean; overload;
begin
  result := notModified(conn, getEtag(f), dateToHTTP(f))
end;

function notModified(conn: ThttpConn; f: Tfile): boolean; overload;
begin
  result := notModified(conn, f.resource)
end;

function Tmainfrm.sendPic(cd: TconnData; idx: integer = -1): boolean;
var
  s, url: string;
  special: (no, graph);
begin
  url := decodeURL(cd.conn.request.url);
  result := FALSE;
  special := no;
  if idx < 0 then
  begin
    s := url;
    if not ansiStartsText('/~img', s) then
      exit;
    Delete(s, 1, 5);
    // converts special symbols
    if ansiStartsText('_graph', s) then
      special := graph
    else if ansiStartsText('_link', s) then
      idx := ICON_LINK
    else if ansiStartsText('_file', s) then
      idx := ICON_FILE
    else if ansiStartsText('_folder', s) then
      idx := ICON_FOLDER
    else if ansiStartsText('_lock', s) then
      idx := ICON_LOCK
    else
      try
        idx := strToInt(s)
      except
        exit
      end;
  end;

  if (special = no) and ((idx < 0) or (idx >= images.count)) then
    exit;

  case special of
    no:
      cd.conn.reply.body := pic2str(idx);
    graph:
      cd.conn.reply.body := getGraphPic(cd);
  end;

  result := TRUE;
  { **
    // browser caching support
    if idx < startingImagesCount then
    s:=intToStr(idx)+':'+etags.values['exe']
    else
    s:=etags.values['icon.'+intToStr(idx)];
    if notModified(cd.conn, s, '') then
    exit;
  }
  cd.conn.reply.mode := HRM_REPLY;
  cd.conn.reply.contentType := 'image/gif';
  cd.conn.reply.bodyMode := RBM_STRING;
  cd.downloadingWhat := DW_ICON;
  cd.lastFN := copy(url, 2, 1000);
end; // sendPic

function getAgentID(s: string): string; overload;
var
  res: string;

  function test(id: string): boolean;
  var
    i: integer;
  begin
    result := FALSE;
    i := pos(id, s);
    case i of
      0:
        exit;
      1:
        res := getTill('/', getTill(' ', s));
    else
      begin
        Delete(s, 1, i - 1);
        res := getTill(';', s);
      end;
    end;
    result := TRUE;
  end; // its

begin
  result := stripChars(s, ['<', '>']);
  if test('Crazy Browser') or test('iPhone') or test('iPod') or test('iPad') or
    test('Chrome') or test('WebKit') // generic webkit browser
    or test('Opera') or test('MSIE') or test('Mozilla') then
    result := res;
end; // getAgentID

function getAgentID(conn: ThttpConn): string; overload;
begin
  result := getAgentID(conn.getHeader('User-Agent'))
end;

procedure setupDownloadIcon(data: TconnData);

  procedure painticon();
  var
    bmp: Tbitmap;
    s: string;
    perc: real;
  begin
    perc := safeDiv(0.0 + data.conn.bytesSentLastItem, data.conn.bytesPartial);
    s := intToStr(trunc(perc * 100)) + '%';
    bmp := getBaseTrayIcon(perc);
    drawTrayIconString(bmp.Canvas, s);
    data.tray_ico.Handle := bmpToHico(bmp);
    bmp.free;
    data.tray.setIcon(data.tray_ico);
    data.tray.setTip(if_(data.conn.reply.bodyMode = RBM_STRING,
      decodeURL(data.conn.request.url), data.lastFN) + trayNL +
      format('%.1f KB/s', [data.averageSpeed / 1000]) + trayNL +
      dotted(data.conn.bytesSentLastItem) + ' bytes sent' + trayNL +
      data.address);
    data.tray.show();
  end; // paintIcon

begin
  if (data = NIL) or (data.conn = NIL) then
    exit;
  if assigned(data.tray) and ((data.conn.state <> HCS_REPLYING_BODY) or
    (data.conn.bytesSentLastItem = data.conn.bytesPartial)) then
  begin
    data.tray.hide();
    freeAndNIL(data.tray);
    data.tray_ico.free;
    exit;
  end;
  if not isSendingFile(data) then
    exit;

  if not data.countAsDownload then
    exit;

  if data.tray = NIL then
  begin
    data.tray := TmyTrayIcon.create(mainfrm);
    data.tray.data := data;
    data.tray_ico := Ticon.create();
    data.tray.onEvent := mainfrm.downloadTrayEvent;
  end;
  if mainfrm.trayfordownloadChk.checked and isSendingFile(data) then
    painticon()
  else
    data.tray.hide();
end; // setupDownloadIcon

function getDynLogFilename(cd: TconnData): string; overload;
var
  d, m, y, w: word;
  u: string;
begin
  decodeDateFully(now(), y, m, d, w);
  if cd = NIL then
    u := ''
  else
    u := nonEmptyConcat('(', cd.usr, ')');
  result := xtpl(logFile.filename, ['%d%', int0(d, 2), '%m%', int0(m, 2), '%y%',
    int0(y, 4), '%dow%', int0(w - 1, 2), '%w%', int0(weekOf(now()), 2),
    '%user%', u]);
end; // getDynLogFilename

procedure applyISOdateFormat();
begin
  if mainfrm.useISOdateChk.checked then
    FormatSettings.ShortDateFormat := 'yyyy-mm-dd'
  else
    FormatSettings.ShortDateFormat := GetLocaleStr(LOCALE_USER_DEFAULT,
      LOCALE_SSHORTDATE, '');
end;

procedure Tmainfrm.add2log(lines: string; cd: TconnData = NIL;
  clr: Tcolor = clDefault);
var
  s, ts, first, rest, addr: string;
begin
  if not logOnVideoChk.checked and
    ((logFile.filename = '') or (logFile.apacheFormat > '')) then
    exit;

  if clr = clDefault then
    clr := clBlack;

  if logDateChk.checked then
  begin
    applyISOdateFormat();
    // this call shouldn't be necessary here, but it's a workaround to this bug www.rejetto.com/forum/?topic=5739
    if logTimeChk.checked then
      ts := datetimeToStr(now())
    else
      ts := dateToStr(now())
  end
  else if logTimeChk.checked then
    ts := timeToStr(now())
  else
    ts := '';

  first := chopLine(lines);
  if lines = '' then
    rest := ''
  else
    rest := reReplace(lines, '^', '> ') + CRLF;

  addr := '';
  if assigned(cd) and assigned(cd.conn) then
  begin
    addr := cd.address + ':' + cd.conn.port + nonEmptyConcat(' {',
      localDNSget(cd.address), '}');
    if freeLoginChk.checked or cd.acceptedCredentials then
      addr := nonEmptyConcat('', cd.usr, '@') + addr;
  end;

  if (logFile.filename > '') and (logFile.apacheFormat = '') then
  begin
    s := ts;
    if (cd = NIL) or (cd.conn = nil) then
      s := s + TAB + '' + TAB + '' + TAB + '' + TAB + ''
    else
      s := s + TAB + cd.usr + TAB + cd.address + TAB + cd.conn.port + TAB +
        localDNSget(cd.address);
    s := s + TAB + first;

    if tabOnLogFileChk.checked then
      s := s + stripChars(reReplace(lines, '^', TAB), [#13, #10])
    else
      s := s + CRLF + rest;

    includeTrailingString(s, CRLF);
    appendFile(getDynLogFilename(cd), s);
  end;

  if not logOnVideoChk.checked then
    exit;

  logbox.selstart := length(logbox.text);
  logbox.SelAttributes.name := logFontName;
  if logFontSize > 0 then
    logbox.SelAttributes.size := logFontSize;
  logbox.SelAttributes.color := clRed;
  logbox.SelText := ts + ' ';
  if addr > '' then
  begin
    logbox.SelAttributes.color := ADDRESS_COLOR;
    logbox.SelText := addr + ' ';
  end;
  logbox.SelAttributes.color := clr;
  logbox.SelText := first + CRLF;
  logbox.SelAttributes.color := clBlue;
  logbox.SelText := rest;

  if (logMaxLines = 0) or (logbox.lines.count <= logMaxLines) then
    exit;
  // found no better way to remove multiple lines with a single move
  logbox.perform(WM_SETREDRAW, 0, 0);
  try
    logbox.selstart := 0;
    logbox.SelLength := logbox.perform(EM_LINEINDEX,
      logbox.lines.count - round(logMaxLines * 0.9), 0);;
    logbox.SelText := '';
    logbox.selstart := length(logbox.text);
  finally
    logbox.perform(WM_SETREDRAW, 1, 0);
    logbox.invalidate();
  end;
end; // add2log

function isBanned(address: string; out comment: string): boolean; overload;
var
  i: integer;
begin
  result := TRUE;
  for i := 0 to length(banlist) - 1 do
    if addressMatch(banlist[i].ip, address) then
    begin
      comment := banlist[i].comment;
      exit;
    end;
  result := FALSE;
end; // isBanned

function isBanned(cd: TconnData): boolean; overload;
begin
  result := assigned(cd) and isBanned(cd.address, cd.banReason)
end;

procedure kickBannedOnes();
var
  i: integer;
  d: TconnData;
begin
  i := 0;
  while i < srv.conns.count do
  begin
    d := conn2data(i);
    if isBanned(d) then
      d.disconnect(first(d.disconnectReason, 'kick banned'));
    inc(i);
  end;
end; // kickBannedOnes

function startServer(): boolean;

  procedure tryPorts(list: array of string);
  var
    i: integer;
  begin
    for i := 0 to length(list) - 1 do
    begin
      srv.port := trim(list[i]);
      if srv.start(listenOn) then
        exit;
    end;
  end; // tryPorts

begin
  result := FALSE;
  if srv.active then
    exit; // fail if already active

  if (localIPlist.indexOf(listenOn) < 0) and (listenOn <> '127.0.0.1') then
    listenOn := '';

  if port > '' then
    tryPorts([port])
  else
    tryPorts(['80', '8080', '280', '10080', '0']);
  if not srv.active then
    exit; // failed
  uptime := now();
  result := TRUE;
end; // startServer

procedure stopServer();
begin
  if assigned(srv) then
    srv.stop()
end;

procedure sayPortBusy(port: string);
var
  fn: string;
begin
  try
    fn := extractFileName(pid2file(port2pid(port)));
  except
    fn := ''
  end;
  msgDlg('Cannot open port.'#13 + if_(fn > '', 'It is already used by ' + fn,
    'Something is blocking, maybe your system firewall.'), MB_ICONERROR);
end; // sayPortBusy

procedure toggleServer();
const
  MSG2 = 'There are %d connections open.'#13'Do you want to close them now?';
begin
  if srv.active then
    stopServer()
  else if not startServer() then
    sayPortBusy(srv.port);
  if (srv.conns.count = 0) or srv.active then
    exit;
  if msgDlg(format(MSG2, [srv.conns.count]), MB_ICONQUESTION + MB_YESNO) = IDYES
  then
    kickByIP('*');
end; // toggleServer

function restartServer(): boolean;
var
  port: string;
begin
  result := FALSE;
  if not srv.active then
    exit;
  port := srv.port;
  srv.stop();
  srv.port := port;
  result := srv.start(listenOn);
end; // restartServer

procedure updatePortBtn();
begin
  if assigned(srv) then
    mainfrm.portBtn.Caption := format('Port: %s',
      [if_(srv.active, srv.port, first(port, 'any'))]);
end; // updatePortBtn

procedure apacheLogCb(re: TregExpr; var res: string; data: pointer);
const
  APACHE_TIMESTAMP_FORMAT = 'dd"/!!!/"yyyy":"hh":"nn":"ss';
var
  code, codes, par: string;
  cmd: char;
  cd: TconnData;

  procedure extra();
  var
    i: integer;
  begin
    // apache log standard for "nothing" is "-", but "-" is a valid filename
    res := '';
    if cd.uploadResults = NIL then
      exit;
    for i := 0 to length(cd.uploadResults) - 1 do
      with cd.uploadResults[i] do
        if reason = '' then
          res := res + fn + '|';
    setLength(res, length(res) - 1);
  end; // extra

begin
  cd := data;
  if cd = NIL then
    exit; // something's wrong
  code := intToStr(HRM2CODE[cd.conn.reply.mode]);
  // first parameter specifies http code to match as CSV, with leading '!' to invert logic
  codes := re.match[1];
  if (codes > '') and ((pos(code, codes) > 0) = (codes[1] = '!')) then
  begin
    res := '-';
    exit;
  end;
  par := re.match[3];
  cmd := re.match[4][1]; // it's case sensitive
  try
    case cmd of
      'a', 'h':
        res := cd.address;
      'l':
        res := '-';
      'u':
        res := first(cd.usr, '-');
      't':
        res := '[' + xtpl(formatDateTime(APACHE_TIMESTAMP_FORMAT, now()),
          ['!!!', MONTH2STR[monthOf(now())]]) + ' ' +
          logFile.apacheZoneString + ']';
      'r':
        res := getTill(CRLF, cd.conn.request.full);
      's':
        res := code;
      'B':
        res := intToStr(cd.conn.bytesSentLastItem);
      'b':
        if cd.conn.bytesSentLastItem = 0 then
          res := '-'
        else
          res := intToStr(cd.conn.bytesSentLastItem);
      'i':
        res := cd.conn.getHeader(par);
      'm':
        res := METHOD2STR[cd.conn.request.method];
      'c':
        if (cd.conn.bytesToSend > 0) and (cd.conn.state = HCS_DISCONNECTED) then
          res := 'X'
        else if cd.disconnectAfterReply then
          res := '-'
        else
          res := '+';
      'e':
        res := getEnvironmentVariable(par);
      'f':
        res := cd.lastFile.name;
      'H':
        res := 'HTTP'; // no way
      'p':
        res := srv.port;
      'z':
        extra(); // extra information specific for hfs
    else
      res := 'UNSUPPORTED';
    end;
  except
    res := 'ERROR'
  end;
end; // apacheLogCb

procedure removeFilesFromComments(files: TStringDynArray);
var
  fn, lastPath, path: string;
  trancheStart, trancheEnd: integer;
  // the tranche is a window within 'files' of items sharing the same path
  ss: TstringList;

  procedure doTheTranche();
  var
    i, b: integer;
    s: string;
  begin
    // comments file
    try
      ss.loadFromFile(lastPath + COMMENTS_FILE);
      for i := trancheStart to trancheEnd do
        try
          ss.Delete(ss.indexOfName(files[i]));
        except
        end;
      ss.saveToFile(path + COMMENTS_FILE);
    except
    end;
    // descript.ion
    if not mainfrm.supportDescriptionChk.checked then
      exit;
    try
      s := loadFile(path + 'descript.ion');
      if s = '' then
        exit;
      if mainfrm.oemForIonChk.checked then
        OEMToCharBuff(@s[1], @s[1], length(s));
      for i := trancheStart to trancheEnd do
      begin
        b := findNameInDescriptionFile(s, files[i]);
        if b > 0 then
          Delete(s, b, findEOL(s, b) - b + 1);
      end;
      saveFile(path + 'descript.ion', s);
    except
    end;
  end; // doTheTranche

begin
  // collect files with same path in tranche, then process it
  sortArray(files);
  trancheStart := 0;
  ss := TstringList.create();
  // we'll use this in doTheTranche(), but create the object once, as an optimization
  try
    ss.caseSensitive := FALSE;
    for trancheEnd := 0 to length(files) - 1 do
    begin
      fn := files[trancheEnd];
      path := getTill(lastDelimiter('\/', fn) + 1, fn);
      if trancheEnd = 0 then
        lastPath := path;
      if path <> lastPath then
      begin
        doTheTranche();
        // init the new tranche
        trancheStart := trancheEnd + 1;
        lastPath := path;
      end;
    end;
    doTheTranche();
  finally
    ss.free
  end;
end; // removeFilesFromComments

procedure runTplImport();
var
  f, fld: Tfile;
begin
  f := Tfile.create(tplFilename);
  fld := Tfile.create(extractFilePath(tplFilename));
  try
    runScript(Template['special:import'], NIL, Template, f, fld);
  finally
    freeAndNIL(f);
    freeAndNIL(fld);
  end;
end; // runTplImport

// returns true if template was patched
function setTplText(text: string): boolean;
(* postponed to next release
  procedure patch290();
  {$J+}
  const
  PATCH: string = '';
  PATCH_RE = '(\[ajax\.mkdir.+)\[special:import';
  var
  se: TstringDynArray;
  i: integer;
  begin
  // is it default tpl?
  if not ansiStartsText('Welcome! This is the default template for HFS 2.3', text) then
  exit;
  // needs to be patched?
  if pos('template revision TR1.',substr(text,1,80)) = 0 then
  exit;
  // calculate the patch once
  if length(PATCH)=0 then
  PATCH:=reGet(defaultTpl, PATCH_RE, 1, '!mis');
  {$J-}
  // find the to-be-patched
  i:=reMatch(text, PATCH_RE, '!mis', 1, @se);
  if i=0 then exit; // something is wrong
  result:=TRUE; // mark
  replace(text, PATCH, i, i+length(se[1])-1); // real patch
  text:=stringReplace(text, 'template revision TR1.', 'template revision TR3.', []); // version stamp
  end;//patchIt
*)
begin
  result := FALSE; // mod by mars
  // patch290();
  // if we'd use optUTF8() here, we couldn't make use of tpl.utf8, because text would not be parsed yet
  Template.fullText := text;
  tplIsCustomized := text <> defaultTpl;
  if boolOnce(tplImport) then
    runTplImport();
end; // setTplText

procedure keepTplUpdated();
begin
  if fileExists(tplFilename) then
  begin
    if newMtime(tplFilename, tplLast) then
      if setTplText(loadFile(tplFilename)) then
        saveFile(tplFilename, Template.fullText);
  end
  else if tplLast <> 0 then
  begin
    tplLast := 0;
    // we have no modified-time in this case, but this will stop the refresh
    setTplText(defaultTpl);
  end;
end; // keepTplUpdated

function getNewSID(): string;
begin
  result := floatToStr(random())
end;

procedure setNewTplFile(fn: string);
begin
  tplFilename := fn;
  tplImport := TRUE;
  tplLast := 0;
end; // setNewTplFile

procedure Tmainfrm.httpEvent(event: ThttpEvent; conn: ThttpConn);
var
  data: TconnData;
  f: Tfile;
  url: string;

  procedure switchToDefaultFile();
  var
    default: Tfile;
  begin
    if (f = NIL) or not f.isFolder() then
      exit;
    default := f.getDefaultFile();
    if default = NIL then
      exit;
    freeIfTemp(f);
    f := default;
  end; // switchToDefaultFile

  function calcAverageSpeed(bytes: int64): integer;
  begin
    result := round(safeDiv(bytes, (now() - data.fileXferStart) * SECONDS))
  end;

  function runEventScript(event: string; table: array of string)
    : string; overload;
  var
    md: TmacroData;
    pleaseFree: boolean;
  begin
    result := trim(eventScripts[event]);
    if result = '' then
      exit;
    fillChar(md, SizeOf(md), 0);
    md.cd := data;
    md.table := toSA(table);
    md.tpl := eventScripts;
    addArray(md.table, ['%event%', event]);
    pleaseFree := FALSE;
    try
      if isReceivingFile(data) then
      begin
        // we must encapsulate it in a Tfile to expose file properties to the script. we don't need to cache the object because we need it only once.
        md.f := Tfile.createTemp(data.uploadDest);
        md.f.size := sizeOfFile(data.uploadDest);
        pleaseFree := TRUE;

        md.folder := data.lastFile;
        if assigned(md.folder) then
          md.f.node := md.folder.node;
      end
      else if assigned(f) then
        md.f := f
      else if assigned(data) then
        md.f := data.lastFile;

      if assigned(md.f) and (md.folder = NIL) then
        md.folder := md.f.getParent();

      tryApplyMacrosAndSymbols(result, md);

    finally
      if pleaseFree then
        freeIfTemp(md.f);
    end;
  end; // runEventScript

  function runEventScript(event: string): string; overload;
  begin
    result := runEventScript(event, [])
  end;

  procedure doLog();
  var
    i: integer;
    url_: string; // an alias, final '_' is to not confuse with the other var
    s: string;
  begin
    if assigned(data) and data.dontLog and (event <> HE_DISCONNECTED) then
      exit; // we exit expect for HE_DISCONNECTED because dontLog is always set AFTER connections, so HE_CONNECTED is always logged. The coupled HE_DISCONNECTED should be then logged too.

    if assigned(data) and (data.preReply = PR_BAN) and not logBannedChk.checked
    then
      exit;

    if conn = NIL then
      url_ := ''
    else
      url_ := decodeURL(conn.request.url);
    if not(event in [HE_OPEN, HE_CLOSE, HE_CONNECTED, HE_DISCONNECTED, HE_GOT])
    then
      if not logIconsChk.checked and (data.downloadingWhat = DW_ICON) or
        not logBrowsingChk.checked and (data.downloadingWhat = DW_FOLDERPAGE) or
        not logProgressChk.checked and (url_ = '/~progress') then
        exit;

    if not(event in [HE_OPEN, HE_CLOSE]) and addressMatch(dontLogAddressMask,
      data.address) then
      exit;

    case event of
      HE_OPEN:
        if logServerstartChk.checked then
          add2log('Server start');
      HE_CLOSE:
        if logServerstopChk.checked then
          add2log('Server stop');
      HE_CONNECTED:
        if logconnectionsChk.checked then
          add2log('Connected', data);
      HE_DISCONNECTED:
        if logDisconnectionsChk.checked then
          add2log('Disconnected' + if_(conn.disconnectedByServer, ' by server')
            + nonEmptyConcat(': ', data.disconnectReason) +
            if_(conn.bytesSent > 0, ' - ' + intToStr(conn.bytesSent) +
            ' bytes sent'), data);
      HE_GOT:
        begin
          i := conn.bytesGot - data.lastBytesGot;
          if i <= 0 then
            exit;
          if logBytesreceivedChk.checked then
            if now() - data.bytesGotGrouping.since <= BYTES_GROUPING_THRESHOLD
            then
              inc(data.bytesGotGrouping.bytes, i)
            else
            begin
              add2log(format('Got %d bytes',
                [i + data.bytesGotGrouping.bytes]), data);
              data.bytesGotGrouping.since := now();
              data.bytesGotGrouping.bytes := 0;
            end;
          inc(data.lastBytesGot, i);
        end;
      HE_SENT:
        begin
          i := conn.bytesSent - data.lastBytesSent;
          if i <= 0 then
            exit;
          if logBytessentChk.checked then
            if now() - data.bytesSentGrouping.since <= BYTES_GROUPING_THRESHOLD
            then
              inc(data.bytesSentGrouping.bytes, i)
            else
            begin
              add2log(format('Sent %d bytes',
                [i + data.bytesSentGrouping.bytes]), data);
              data.bytesSentGrouping.since := now();
              data.bytesSentGrouping.bytes := 0;
            end;
          inc(data.lastBytesSent, i);
        end;
      HE_REQUESTED:
        if not logOnlyServedChk.checked or
          (conn.reply.mode in [HRM_REPLY, HRM_REPLY_HEADER, HRM_REDIRECT]) then
        begin
          data.logLaterInApache := TRUE;
          if logRequestsChk.checked then
          begin
            s := substr(conn.getHeader('Range'), 7);
            if s > '' then
              s := TAB + '[' + s + ']';
            add2log(format('Requested %s %s%s',
              [METHOD2STR[conn.request.method], url_, s]), data);
          end;
          if dumprequestsChk.checked then
            add2log('Request dump' + CRLF + conn.request.full, data);
        end;
      HE_REPLIED:
        if logRepliesChk.checked then
          case conn.reply.mode of
            HRM_REPLY:
              if not data.fullDLlogged then
                add2log(format('Served %s',
                  [smartsize(conn.bytesSentLastItem)]), data);
            HRM_REPLY_HEADER:
              add2log('Served head', data);
            HRM_NOT_MODIFIED:
              add2log('Not modified, use cache', data);
            HRM_REDIRECT:
              add2log(format('Redirected to %s', [conn.reply.url]), data);
          else
            if not logOnlyServedChk.checked then
              add2log(format('Not served: %d - %s', [HRM2CODE[conn.reply.mode],
                HRM2STR[conn.reply.mode]]) + nonEmptyConcat(': ',
                data.error), data);
          end;
      HE_POST_FILE:
        if logUploadsChk.checked and (data.uploadFailed = '') then
          add2log(format('Uploading %s', [data.uploadSrc]), data);
      HE_POST_END_FILE:
        if logUploadsChk.checked then
          if data.uploadFailed = '' then
            add2log(format('Fully uploaded %s - %s @ %sB/s',
              [data.uploadSrc, smartsize(conn.bytesPostedLastItem),
              smartsize(calcAverageSpeed(conn.bytesPostedLastItem))]), data)
          else
            add2log(format('Upload failed %s', [data.uploadSrc]), data);
      HE_LAST_BYTE_DONE:
        if logFulldownloadsChk.checked and data.countAsDownload and
          (data.downloadingWhat in [DW_FILE, DW_ARCHIVE]) then
        begin
          data.fullDLlogged := TRUE;
          add2log(format('Fully downloaded - %s @ %sB/s - %s',
            [smartsize(conn.bytesSentLastItem),
            smartsize(calcAverageSpeed(conn.bytesSentLastItem)), url_]), data);
        end;
    end;

    { apache format log is only related to http events, that's why it resides
      { inside httpEvent(). moreover, it needs to access to some variables. }
    if (logFile.filename = '') or (logFile.apacheFormat = '') or (data = NIL) or
      not data.logLaterInApache or
      not(event in [HE_LAST_BYTE_DONE, HE_DISCONNECTED]) then
      exit;

    data.logLaterInApache := FALSE;
    s := xtpl(logFile.apacheFormat, ['\t', TAB, '\r', #13, '\n', #10, '\"', '"',
      '\\', '\']);
    s := reCB('%(!?[0-9,]+)?(\{([^}]+)\})?>?([a-z])', s, apacheLogCb, data);
    appendFile(getDynLogFilename(data), s + CRLF);
  end; // doLog

  function limitsExceededOnConnection(): boolean;
  begin
    if noLimitsFor(data.account) then
      result := FALSE
    else
      result := (maxConnections > 0) and (srv.conns.count > maxConnections) or
        (maxConnectionsIP > 0) and
        (countConnectionsByIP(data.address) > maxConnectionsIP) or (maxIPs > 0)
        and (countIPs() > maxIPs)
  end; // limitsExceededOnConnection

  function limitsExceededOnDownload(): boolean;
  var
    was: string;
  begin
    result := FALSE;
    data.disconnectReason := '';

    if data.conn.ignoreSpeedLimit then
      exit;

    if (maxContempDLs > 0) and (countDownloads() > maxContempDLs) or
      (maxContempDLsIP > 0) and (countDownloads(data.address) > maxContempDLsIP)
    then
      data.disconnectReason := 'Max simultaneous downloads'
    else if (maxIPsDLing > 0) and (countIPs(TRUE) > maxIPsDLing) then
      data.disconnectReason := 'Max simultaneous addresses downloading'
    else if preventLeechingChk.checked and
      (countDownloads(data.address, '', f) > 1) then
      data.disconnectReason := 'Leeching';

    was := data.disconnectReason;
    runEventScript('download');

    result := data.disconnectReason > '';
    if not result then
      exit;
    data.countAsDownload := FALSE;
    getPage(if_(was = data.disconnectReason, 'max contemp downloads',
      'deny'), data);
  end; // limitsExceededOnDownload

  procedure extractParams();
  var
    s: string;
    i: integer;
  begin
    s := url;
    url := chop('?', s);
    data.urlvars.clear();
    if s > '' then
      extractStrings(['&'], [], @s[1], data.urlvars);
    for i := 0 to data.urlvars.count - 1 do
      data.urlvars[i] := decodeURL(xtpl(data.urlvars[i], ['+', ' ']));
  end; // extractParams

  procedure closeUploadingFile();
  begin
    if data.f = NIL then
      exit;
    closeFile(data.f^);
    dispose(data.f);
    data.f := NIL;
  end; // closeUploadingFile

// close and eventually delete/rename
  procedure closeUploadingFile_partial();
  begin
    if (data = NIL) or (data.f = NIL) then
      exit;
    closeUploadingFile();
    if deletePartialUploadsChk.checked then
      deleteFile(data.uploadDest)
    else if renamePartialUploads = '' then
      exit;
    if ipos('%name%', renamePartialUploads) = 0 then
      renameFile(data.uploadDest, data.uploadDest + renamePartialUploads)
    else
      renameFile(data.uploadDest, extractFilePath(data.uploadDest) +
        xtpl(renamePartialUploads, ['%name%',
        extractFileName(data.uploadDest)]));
  end; // closeUploadingFile_partial

  function isDownloadManagerBrowser(): boolean;
  begin
    result := (pos('GetRight', data.agent) > 0) or (pos('FDM', data.agent) > 0)
      or (pos('FlashGet', data.agent) > 0)
  end; // isDownloadManagerBrowser

  procedure logUploadFailed();
  begin
    if not logUploadsChk.checked then
      exit;
    add2log(format('Upload failed for %s: %s', [data.uploadSrc,
      data.uploadFailed]), data);
  end; // logUploadFile

  function eventToFilename(event: string; table: array of string): string;
  var
    i: integer;
  begin
    result := trim(stripChars(runEventScript(event, table), [TAB, #10, #13]));
    // turn illegal chars into underscores
    for i := 1 to length(result) do
      if result[i] in ILLEGAL_FILE_CHARS - [':', '\'] then
        result[i] := '_';
  end; // eventToFilename

  procedure getUploadDestinationFileName();
  var
    i: integer;
    fn, ext, s: string;
  begin
    new(data.f);
    fn := data.uploadSrc;

    data.uploadDest := f.resource + '\' + fn;
    assignFile(data.f^, data.uploadDest);

    // see if an event script wants to change the name
    s := eventToFilename('upload name', []);

    if validFilepath(s) then // is it valid anyway?
    begin
      if pos('\', s) = 0 then
      // it's just the file name, no path specified: must include the path of the current folder
        s := f.resource + '\' + s;
      // ok, we'll use this new name
      data.uploadDest := s;
      fn := extractFileName(s);
    end;

    if numberFilesOnUploadChk.checked then
    begin
      ext := ExtractFileExt(fn);
      setLength(fn, length(fn) - length(ext));
      i := 0;
      while fileExists(data.uploadDest) do
      begin
        inc(i);
        data.uploadDest := format('%s\%s (%d)%s', [f.resource, fn, i, ext]);
      end;
    end;
    assignFile(data.f^, data.uploadDest);
  end; // getUploadDestinationFileName

  procedure sessionSetup();
  begin
    if (data = NIL) or assigned(data.session) then
      exit;
    data.sessionID := conn.getCookie(SESSION_COOKIE);
    if data.sessionID = '' then
    begin
      data.sessionID := getNewSID();
      conn.setCookie(SESSION_COOKIE, data.sessionID, ['path', '/'], 'HttpOnly');
      // the session is site-wide, even if this request was related to a folder
    end
    else
      try
        data.session := sessions.Objects[sessions.indexOf(data.sessionID)
          ] as THashedStringList
      except
      end;
    if data.usr = '' then
    begin
      data.usr := data.sessionGet('user');
      data.pwd := data.sessionGet('password');
    end;
    if (data.usr = '') and (conn.request.user > '') then
    begin
      data.usr := conn.request.user;
      data.pwd := conn.request.pwd;
    end;
    if (data.usr = '') <> (data.account = NIL) then
      data.account := getAccount(data.usr);
  end; // sessionSetup

  procedure serveTar();
  var
    tar: TtarStream;
    nofolders, selection, itsAsearch: boolean;

    procedure addFolder(f: Tfile; ignoreConnFilters: boolean = FALSE);
    var
      i, ofs: integer;
      listing: TfileListing;
      fi: Tfile;
      fIsTemp: boolean;
      s: string;
    begin
      if not f.accessFor(data) then
        exit;
      listing := TfileListing.create();
      try
        listing.ignoreConnFilter := ignoreConnFilters;
        listing.fromFolder(f, data, shouldRecur(data));
        fIsTemp := f.isTemp();
        ofs := length(f.resource) - length(f.name) + 1;
        for i := 0 to length(listing.dir) - 1 do
        begin
          if conn.state = HCS_DISCONNECTED then
            break;

          fi := listing.dir[i];
          // we archive only files, folders are just part of the path
          if not fi.isFile() then
            continue;
          if not fi.accessFor(data) then
            continue;

          // build the full path of this file as it will be in the archive
          if nofolders then
            s := fi.name
          else if fIsTemp and not(FA_SOLVED_LNK in fi.flags) then
            s := copy(fi.resource, ofs, MAXINT)
            // pathTill won't work this case, because f.parent is an ancestor but not necessarily the parent
          else
            s := fi.pathTill(f.parent);
          // we want the path to include also f, so stop at f.parent

          tar.addFile(fi.resource, s);
        end
      finally
        listing.free
      end;
    end; // addFolder

    procedure addSelection();
    var
      i: integer;
      s: string;
      ft: Tfile;
    begin
      selection := FALSE;
      for i := 0 to data.postVars.count - 1 do
        if sameText('selection', data.postVars.names[i]) then
        begin
          selection := TRUE;
          s := decodeURL(getTill('#', data.postVars.valueFromIndex[i]));
          // omit #anchors
          if dirCrossing(s) then
            continue;
          ft := findFilebyURL(s, f);
          if ft = NIL then
            continue;

          try
            if not ft.accessFor(data) then
              continue;
            // case folder
            if ft.isFolder() then
            begin
              addFolder(ft, TRUE);
              continue;
            end;
            // case file
            if not fileExists(ft.resource) then
              continue;
            if nofolders then
              s := substr(s, lastDelimiter('\/', s) + 1);
            tar.addFile(ft.resource, s);
          finally
            freeIfTemp(ft)
          end;
        end;
    end; // addSelection

  begin
    if not f.hasRecursive(FA_ARCHIVABLE) then
    begin
      getPage('deny', data);
      exit;
    end;
    data.downloadingWhat := DW_ARCHIVE;
    data.countAsDownload := TRUE;
    if limitsExceededOnDownload() then
      exit;

    // this will let you get all files as flatly arranged in the root of the archive, without folders
    nofolders := not stringExists(data.postVars.values['nofolders'],
      ['', '0', 'false']);
    itsAsearch := data.urlvars.values['search'] > '';

    tar := TtarStream.create(); // this is freed by ThttpSrv
    try
      tar.fileNamesOEM := oemTarChk.checked;
      addSelection();
      if not selection then
        addFolder(f);

      if tar.count = 0 then
      begin
        tar.free;
        data.disconnectReason := 'There is no file you are allowed to download';
        getPage('deny', data, f);
        exit;
      end;
      data.fileXferStart := now();
      conn.reply.mode := HRM_REPLY;
      conn.reply.contentType := DEFAULT_MIME;
      conn.reply.bodyMode := RBM_STREAM;
      conn.reply.bodyStream := tar;

      if f.name = '' then
        exit; // can this really happen?
      data.lastFN := if_(f.name = '/', 'home', f.name) + '.' +
        if_(selection, 'selection', if_(itsAsearch, 'search', 'folder')
        ) + '.tar';
      data.lastFN := first(eventToFilename('archive name', ['%archive-name%',
        data.lastFN, '%mode%', if_(selection, 'selection', 'folder'),
        '%archive-size%', intToStr(tar.size)]), data.lastFN);
      if not noContentdispositionChk.checked then
        conn.addHeader('Content-Disposition: attachment; filename="' +
          data.lastFN + '";');
    except
      tar.free
    end;
  end; // serveTar

  procedure checkCurrentAddress();
  begin
    if selftesting then
      exit;
    if limitsExceededOnConnection() then
      data.preReply := PR_OVERLOAD;
    if isBanned(data) then
    begin
      data.disconnectReason := 'banned';
      data.preReply := PR_BAN;
      if noReplyBan then
        conn.reply.mode := HRM_CLOSE;
    end;
  end; // checkCurrentAddress

  procedure handleRequest();
  var
    dlForbiddenForWholeFolder, specialGrant: boolean;
    urlCmd: string;

    function accessGranted(forceFile: Tfile = NIL): boolean;
    var
      m: TStringDynArray;
      fTemp: Tfile;
    begin
      result := FALSE;
      if assigned(forceFile) then
        f := forceFile;
      if f = NIL then
        exit;
      if f.isFile() and (dlForbiddenForWholeFolder or f.isDLforbidden()) then
      begin
        getPage('deny', data);
        exit;
      end;
      result := f.accessFor(data);
      // ok, you are referring a section of the template, which virtually resides in the root because of the url starting with /~
      // but you don't have access rights to the root. We'll let you pass if it's actually a section and you are using it from a folder that you have access to.
      if not result and (f = rootFile) and ansiStartsStr('~', urlCmd) and
        Template.sectionExist(copy(urlCmd, 2, MAXINT)) and
        (0 < reMatch(conn.getHeader('Referer'),
        '://([^@]*@)?' + getSafeHost(data) + '(/.*)', 'i', 1, @m)) then
      begin
        fTemp := findFilebyURL(m[2]);
        result := assigned(fTemp) and fTemp.accessFor(data);
        specialGrant := result;
        freeIfTemp(fTemp);
      end;
      if result then
        exit;
      conn.reply.realm := f.getShownRealm();
      runEventScript('unauthorized');
      getPage('unauthorized', data);
      // log anyone trying to guess the password
      if (forceFile = NIL) and stringExists(data.usr,
        getAccountList(TRUE, FALSE)) and logOtherEventsChk.checked then
        add2log('Login failed', data);
    end; // accessGranted

    function isAllowedReferer(): boolean;
    var
      r: string;
    begin
      result := TRUE;
      if allowedReferer = '' then
        exit;
      r := hostFromURL(conn.getHeader('Referer'));
      if (r = '') or (r = getSafeHost(data)) then
        exit;
      result := fileMatch(allowedReferer, r);
    end; // isAllowedReferer

    procedure replyWithString(s: string);
    begin
      if (data.disconnectReason > '') and not data.disconnectAfterReply then
      begin
        getPage('deny', data);
        exit;
      end;

      if conn.reply.contentType = '' then
        conn.reply.contentType := if_(trim(getTill('<', s)) = '', 'text/html',
          'text/plain');
      conn.reply.mode := HRM_REPLY;
      conn.reply.bodyMode := RBM_STRING;
      conn.reply.body := s;
      compressReply(data);
    end; // replyWithString

    procedure deletion();
    var
      i: integer;
      asUrl, s: string;
      doneRes, done, ERRORS: TStringDynArray;
    begin
      if (conn.request.method <> HM_POST) or
        (data.postVars.values['action'] <> 'delete') or
        not accountAllowed(FA_DELETE, data, f) then
        exit;

      doneRes := NIL;
      ERRORS := NIL;
      done := NIL;
      for i := 0 to data.postVars.count - 1 do
        if sameText('selection', data.postVars.names[i]) then
        begin
          asUrl := decodeURL(getTill('#', data.postVars.valueFromIndex[i]));
          // omit #anchors
          s := uri2disk(asUrl, f);
          if s = '' then
            continue;

          if not fileOrDirExists(s) then
            continue; // ignore

          runEventScript('file deleting', ['%item-deleting%', s]);
          moveToBin(toSA([s, s + '.md5', s + COMMENT_FILE_EXT]), TRUE);
          if fileOrDirExists(s) then
          begin
            addString(asUrl, ERRORS);
            continue; // this was not deleted. permissions problem?
          end;

          addString(s, doneRes);
          addString(asUrl, done);
          runEventScript('file deleted', ['%item-deleted%', s]);
        end;

      removeFilesFromComments(doneRes);

      if logDeletionsChk.checked and assigned(done) then
        add2log('Deleted files in ' + url + CRLF + join(CRLF, done), data);
      if logDeletionsChk.checked and assigned(ERRORS) then
        add2log('Failed deletion in ' + url + CRLF + join(CRLF, ERRORS), data);
    end; // deletion

    function getAccountRedirect(): string;
    var
      acc: Paccount;
    begin
      result := '';
      acc := accountRecursion(data.account, ARSC_REDIR);
      if acc = NIL then
        exit;
      result := acc.redir;
      if (result = '') or ansiContainsStr(result, '://') then
        exit;
      // if it's not a complete url, it may require some fixing
      if not ansiStartsStr('/', result) then
        result := '/' + result;
      result := xtpl(result, ['\', '/']);
    end; // getAccountRedirect

    function addNewAddress(): boolean;
    begin
      result := ipsEverConnected.indexOf(data.address) < 0;
      if not result then
        exit;
      ipsEverConnected.add(data.address);
    end; // addNewAddress

  var
    b: boolean;
    s: string;
    i: integer;
    section: PTemplateSection;
  begin
    // eventually override the address
    if addressMatch(forwardedMask, conn.address) then
    begin
      data.address := getTill(':',
        getTill(',', conn.getHeader('x-forwarded-for')));
      if not checkAddressSyntax(data.address) then
        data.address := conn.address;
    end;

    checkCurrentAddress();

    // update list
    if (data.preReply = PR_NONE) and addNewAddress() and ipsEverFrm.visible then
      ipsEverFrm.refreshData();

    data.requestTime := now();
    data.downloadingWhat := DW_UNK;
    data.fullDLlogged := FALSE;
    data.countAsDownload := FALSE;
    conn.reply.contentType := '';
    specialGrant := FALSE;

    data.lastFile := NIL; // auto-freeing

    with objByIP(data.address) do
    begin
      if speedLimitIP < 0 then
        limiter.maxSpeed := MAXINT
      else
        limiter.maxSpeed := round(speedLimitIP * 1000);
      if conn.limiters.indexOf(limiter) < 0 then
        conn.limiters.add(limiter);
    end;

    conn.addHeader('Accept-Ranges: bytes');
    if sendHFSidentifierChk.checked then
      conn.addHeader('Server: HFS ' + HFS.Consts.VERSION);

    case data.preReply of
      PR_OVERLOAD:
        begin
          data.disconnectReason := 'limits exceeded';
          getPage('overload', data);
        end;
      PR_BAN:
        begin
          getPage('ban', data);
          conn.reply.reason := 'Banned: ' + data.banReason;
        end;
    end;

    runEventScript('pre-filter-request');

    if (length(conn.request.user) > 100) or
      anycharIn('/\:?*<>|', conn.request.user) then
    begin
      conn.reply.mode := HRM_BAD_REQUEST;
      exit;
    end;

    if not(conn.request.method in [HM_GET, HM_HEAD, HM_POST]) then
    begin
      conn.reply.mode := HRM_METHOD_NOT_ALLOWED;
      exit;
    end;
    inc(hitsLogged);

    if data.preReply <> PR_NONE then
      exit;

    url := conn.request.url;
    extractParams();
    url := decodeURL(url);

    data.lastFN := extractFileName(xtpl(url, ['/', '\']));
    data.agent := getAgentID(conn);

    if selftesting and (url = 'test') then
    begin
      replyWithString('HFS OK');
      exit;
    end;

    sessionSetup();
    if data.postVars.indexOfName('__USER') >= 0 then
    begin
      s := data.postVars.values['__USER'];
      data.account := getAccount(s);
      if data.account = NIL then
        if s = '' then // logout
        begin
          s := 'ok';
          data.usr := '';
          data.pwd := '';
        end
        else
          s := 'username not found'
      else
      begin
        data.usr := s;
        { I opted to use double md5 for this authentication method so that in the
          future we may make this work even if we store hashed password on the server.
          In such case we would not be able to calculate pwd+sessionID because we'd had no clear pwd.
          By relying on md5(pwd) instead of pwd, we will avoid such problem. }
        s := data.postVars.values['__PASSWORD_MD5'];
        if (s > '') and (s = strMD5(strMD5(data.account.pwd) + data.sessionID))
          or (data.postVars.values['__PASSWORD'] = data.account.pwd) then
        begin
          s := 'ok';
          data.pwd := data.account.pwd;
          data.sessionSet('user', data.usr);
          data.sessionSet('password', data.pwd);
        end
        else
        begin
          s := 'bad password';
          data.account := NIL;
          data.usr := '';
        end;
      end;
      if data.postVars.values['__AJAX'] = '1' then
      begin
        replyWithString(s);
        exit;
      end;
    end;

    // this is better to be refresh, because a user may be deleted meantime
    data.account := getAccount(data.usr);
    conn.ignoreSpeedLimit := noLimitsFor(data.account);

    // all URIs must begin with /
    if (url = '') or (url[1] <> '/') then
    begin
      conn.reply.mode := HRM_BAD_REQUEST;
      exit;
    end;

    runEventScript('request');
    if data.disconnectReason > '' then
    begin
      getPage('deny', data);
      exit;
    end;
    if conn.reply.mode = HRM_REDIRECT then
      exit;

    if ansiStartsStr('/~img', url) then
    begin
      if not sendPic(data) then
        getPage('not found', data);
      exit;
    end;
    if data.urlvars.values['mode'] = 'jquery' then
    begin
      replyWithString(getRes('jquery'));
      conn.reply.contentType := 'text/javascript';
      exit;
    end;

    // forbid using invalid credentials
    if not freeLoginChk.checked and not specialGrant then
      if assigned(data.account) and (data.account.pwd <> data.pwd) or
        (data.account = NIL) and (data.usr > '') and
        not usersInVFS.match(data.usr, data.pwd) then
      begin
        data.acceptedCredentials := FALSE;
        runEventScript('unauthorized');
        getPage('unauthorized', data);
        conn.reply.realm := 'Invalid login';
        exit;
      end
      else
        data.acceptedCredentials := TRUE;

    f := findFilebyURL(url);
    urlCmd := ''; // urlcmd is only if the file doesn't exist
    if f = NIL then
    begin
      // maybe the file doesn't exist because the URL has a final command in it
      // move last url part from 'url' into 'urlCmd'
      urlCmd := url;
      url := chop(lastDelimiter('/', urlCmd) + 1, 0, urlCmd);
      // we know an urlCmd must begin with ~
      // favicon is handled as an urlCmd: we provide HFS icon.
      // an non-existent ~file will be detected a hundred lines below.
      if ansiStartsStr('~', urlCmd) or (urlCmd = 'favicon.ico') then
        f := findFilebyURL(url);
    end;
    if f = NIL then
    begin
      if sameText(url, '/robots.txt') and stopSpidersChk.checked then
        replyWithString('User-agent: *' + CRLF + 'Disallow: /')
      else
        getPage('not found', data);
      exit;
    end;
    if f.isFolder() and not ansiEndsStr('/', url) then
    begin
      conn.reply.mode := HRM_MOVED;
      conn.reply.url := f.url();
      // we use f.url() instead of just appending a "/" to url because of problems with non-ansi chars http://www.rejetto.com/forum/?topic=7837
      exit;
    end;
    if f.isFolder() and (urlCmd = '') and (data.urlvars.indexOfName('mode') < 0)
    then
      switchToDefaultFile();
    if enableNoDefaultChk.checked and (urlCmd = '~nodefault') then
      urlCmd := '';

    if f.isRealFolder() and not System.SysUtils.DirectoryExists(f.resource) or
      f.isFile() and not fileExists(f.resource) then
    begin
      getPage('not found', data);
      exit;
    end;
    dlForbiddenForWholeFolder := f.isDLforbidden();

    if not accessGranted() then
      exit;

    if urlCmd = 'favicon.ico' then
    begin
      sendPic(data, 23);
      exit;
    end;

    if urlCmd = '~login' then
      if conn.request.user = '' then
      begin // issue a login dialog
        getPage('unauthorized', data);
        if loginRealm > '' then
          conn.reply.realm := loginRealm;
        exit;
      end
      else
      begin
        conn.reply.mode := HRM_REDIRECT;
        conn.reply.url := first(getAccountRedirect(), url);
        exit;
      end;

    b := urlCmd = '~upload+progress';
    if (b or (urlCmd = '~upload') or (urlCmd = '~upload-no-progress')) then
    begin
      if not f.isRealFolder() then
        getPage('deny', data)
      else if accountAllowed(FA_UPLOAD, data, f) then
        getPage(if_(b, 'upload+progress', 'upload'), data, f)
      else
      begin
        getPage('unauthorized', data);
        runEventScript('unauthorized');
      end;
      if b then // fix for IE6
      begin
        data.disconnectAfterReply := TRUE;
        data.disconnectReason := 'IE6 workaround';
      end;
      exit;
    end;

    if (conn.request.method = HM_POST) and assigned(data.uploadResults) then
    begin
      getPage('upload-results', data, f);
      exit;
    end;

    // provide access to any [section] in the tpl, included [progress]
    if data.urlvars.values['mode'] = 'section' then
      s := first(data.urlvars.values['id'], 'no-id')
      // no way, you must specify the id
    else if (f = rootFile) and (urlCmd > '') then
      s := substr(urlCmd, 2)
    else
      s := '';
    if (s > '') and f.isFolder() and not ansiStartsText('special:', s) then
      with tplFromFile(f) do // temporarily builds from diff tpls
        try
          // NB: section [] is not accessible, because of the s>'' test
          section := getSection(s);
          if assigned(section) and not section.nourl then
          // it has to exist and be accessible
          begin
            getPage(s, data, f, me());
            exit;
          end;
        finally
          free
        end;

    if f.isFolder() and not(FA_BROWSABLE in f.flags) and
      stringExists(urlCmd, ['', '~folder.tar', '~files.lst']) then
    begin
      getPage('deny', data);
      exit;
    end;

    if not isAllowedReferer() or f.isFile() and f.isDLforbidden() then
    begin
      getPage('deny', data);
      exit;
    end;

    if (urlCmd = '~folder.tar') or (data.urlvars.values['mode'] = 'archive')
    then
    begin
      serveTar();
      exit;
    end;

    // please note: we accept also ~files.lst.m3u
    if ansiStartsStr('~files.lst', urlCmd) or f.isFolder() and
      (data.urlvars.values['tpl'] = 'list') then
    begin
      // load from external file
      s := cfgPath + FILELIST_TPL_FILE;
      if newMtime(s, lastFilelistTpl) then
        filelistTpl.fullText := loadFile(s);
      // if no file is given, load from internal resource
      if not fileExists(s) and (lastFilelistTpl > 0) then
      begin
        lastFilelistTpl := 0;
        filelistTpl.fullText := getRes('filelistTpl');
      end;

      data.downloadingWhat := DW_FOLDERPAGE;
      data.disconnectAfterReply := TRUE; // needed for IE6... ugh...
      data.disconnectReason := 'IE6 workaround';
      replyWithString(trim(getFolderPage(f, data, filelistTpl)));
      exit;
    end;

    // from here on, we manage only services with no urlCmd.
    // a non empty urlCmd means the url resource was not found.
    if urlCmd > '' then
    begin
      getPage('not found', data);
      exit;
    end;

    case conn.request.method of
      HM_GET, HM_POST:
        begin
          conn.reply.mode := HRM_REPLY;
          lastActivityTime := now();
        end;
      HM_HEAD:
        conn.reply.mode := HRM_REPLY_HEADER;
    end;

    data.lastFile := f; // auto-freeing

    if f.isFolder() then
    begin
      deletion();

      data.downloadingWhat := DW_FOLDERPAGE;
      if DMbrowserTplChk.checked and isDownloadManagerBrowser() then
        s := getFolderPage(f, data, dmBrowserTpl)
      else
        s := getFolderPage(f, data, Template);
      if conn.reply.mode <> HRM_REDIRECT then
        replyWithString(s);
      exit;
    end;

    data.countAsDownload := f.shouldCountAsDownload();
    if data.countAsDownload and limitsExceededOnDownload() then
      exit;

    if notModified(conn, f) then
      exit;

    setupDownloadIcon(data);
    data.eta.idx := 0;
    conn.reply.contentType := name2mimetype(f.name, DEFAULT_MIME);
    conn.reply.bodyMode := RBM_FILE;
    conn.reply.body := f.resource;
    data.downloadingWhat := DW_FILE;
    { I guess this would not help in any way for files since we are already handling the 'if-modified-since' field
      try
      conn.addHeader('ETag: '+getEtag(f.resource));
      except end;
    }

    data.fileXferStart := now();
    if data.countAsDownload and (flashOn = 'download') then
      flash();

    b := (openInBrowser <> '') and fileMatch(openInBrowser, f.name) or
      inBrowserIfMIME and (conn.reply.contentType <> DEFAULT_MIME);

    s := first(eventToFilename('download name', []), f.name);
    // a script can eventually decide the name
    // N-th workaround for IE. The 'accept' check should let us know if the save-dialog is displayed. More information at www.rejetto.com/forum/?topic=6275
    if (data.agent = 'MSIE') and (conn.getHeader('Accept') = '*/*') then
      s := xtpl(s, [' ', '%20']);
    if not noContentdispositionChk.checked or not b then
      conn.addHeader('Content-Disposition: ' + if_(not b, 'attachment; ') +
        'filename="' + s + '";');
  end; // handleRequest

  procedure lastByte();

    procedure incDLcount(f: Tfile; res: string);
    begin
      if (f = NIL) or f.isTemp() then
        autoupdatedFiles.incInt(res)
      else
        f.DLcount := 1 + f.DLcount
    end;

  var
    archive: TarchiveStream;
    i: integer;
  begin
    if data.countAsDownload then
      inc(downloadsLogged);
    // workaround for a bug that was fixed in Wget/1.10
    if stringExists(data.agent, ['Wget/1.7', 'Wget/1.8.2', 'Wget/1.9',
      'Wget/1.9.1']) then
      data.disconnect('wget bug workaround (consider updating wget)');
    VFScounterMod := TRUE;
    case data.downloadingWhat of
      DW_FILE:
        if assigned(data) then
          incDLcount(data.lastFile, data.lastFile.resource);
      DW_ARCHIVE:
        begin
          archive := conn.reply.bodyStream as TarchiveStream;
          for i := 0 to length(archive.flist) - 1 do
            incDLcount(Tfile(archive.flist[i].data), archive.flist[i].src);
        end;
    end;
    if data.countAsDownload then
      runEventScript('download completed');
  end; // lastByte

  function canWriteFile(): boolean;
  begin
    result := FALSE;
    if data.f = NIL then
      exit;
    result := minDiskSpace <= diskSpaceAt(data.uploadDest) div MEGA;
    if result then
      exit;
    closeUploadingFile_partial();
    data.uploadFailed := 'Minimum disk space reached.';
  end; // canWriteFile

  function complyUploadFilter(): boolean;

    function getMask(): string;
    begin
      if f.isTemp() then
        result := f.parent.uploadFilterMask
      else
        result := f.uploadFilterMask;
      if result = '' then
        result := '\' + PROTECTED_FILES_MASK;
      // the user can disable this default filter by inputing * as mask
    end;

  begin
    result := validFilename(data.uploadSrc) and not sameText(data.uploadSrc,
      DIFF_TPL_FILE) // never allow this
      and not isExtension(data.uploadSrc, '.lnk') // security matters (by mars)
      and fileMatch(getMask(), data.uploadSrc);
    if not result then
      data.uploadFailed := 'File name or extension forbidden.';
  end; // complyUploadFilter

  function canCreateFile(): boolean;
  begin
    IOresult;
    rewrite(data.f^, 1);
    result := IOresult = 0;
    if result then
      exit;
    data.uploadFailed := 'Error creating file.';
  end; // canCreateFile

var
  ur: TuploadResult;
  i: integer;
begin
  if assigned(conn) and (conn.getLockCount <> 1) then
    add2log('please report on the forum about this message');

  f := NIL;
  data := NIL;
  if assigned(conn) then
    data := conn.data;
  if assigned(data) then
    data.lastActivityTime := now();

  if dumpTrafficChk.checked and (event in [HE_GOT, HE_SENT]) then
    appendFile(exePath + 'hfs-dump.bin', TLV(if_(event = HE_GOT, 1, 2),
      TLV(10, str_(now())) + TLV(11, data.address) + TLV(12, conn.port) +
      TLV(13, conn.eventData)));

  if preventStandbyChk.checked and assigned(setThreadExecutionState) then
    setThreadExecutionState(1);

  // this situation can happen when there is a call to processMessage() before this function ends
  if (data = NIL) and (event in [HE_REQUESTED, HE_GOT]) then
    exit;

  case event of
    HE_CANT_OPEN_FILE:
      data.error := 'Can''t open file';
    HE_OPEN:
      begin
        startBtn.hide();
        updateUrlBox();
        // this happens when the server is switched on programmatically
        usingFreePort := port = '';
        updatePortBtn();
        runEventScript('server start');
      end;
    HE_CLOSE:
      begin
        startBtn.show();
        updatePortBtn();
        updateUrlBox();
        runEventScript('server stop');
      end;
    HE_REQUESTING:
      begin
        // do some clearing, due for persistent connections
        data.vars.clear();
        data.urlvars.clear();
        data.postVars.clear();
        data.tplCounters.clear();
        refreshConn(data);
      end;
    HE_GOT_HEADER:
      runEventScript('got header');
    HE_REQUESTED:
      begin
        data.dontLog := FALSE;
        handleRequest();
        // we save the value because we need it also in HE_REPLY, and temp files are not avaliable there
        data.dontLog := data.dontLog or assigned(f) and
          f.hasRecursive(FA_DONT_LOG);
        if f <> data.lastFile then
          freeIfTemp(f);
        refreshConn(data);
      end;
    HE_STREAM_READY:
      begin
        i := length(data.disconnectReason);
        runEventScript('stream ready');
        if (i = 0) and (data.disconnectReason > '') then
        // only if it was not already disconnecting
        begin
          conn.reply.additionalHeaders := '';
          // content-disposition would prevent the browser
          getPage('deny', data);
          conn.initInputStream();
        end;
      end;
    HE_REPLIED:
      begin
        setupDownloadIcon(data); // remove the icon
        data.lastBytesGot := 0;
        if data.disconnectAfterReply then
          data.disconnect('replied');
        if updateASAP > '' then
          data.disconnect('updating');
        refreshConn(data);
      end;
    HE_LAST_BYTE_DONE:
      begin
        if (conn.reply.mode = HRM_REPLY) and
          (data.downloadingWhat in [DW_FILE, DW_ARCHIVE]) then
          lastByte();
        runEventScript('request completed');
      end;
    HE_CONNECTED:
      begin
        // ** lets see if this helps with speed
        i := -1;
        WSocket_setsockopt(conn.sock.HSocket, IPPROTO_TCP, TCP_NODELAY, @i,
          SizeOf(i));

        data := TconnData.create(conn);
        conn.limiters.add(globalLimiter);
        // every connection is bound to the globalLimiter
        conn.sndBuf := STARTING_SNDBUF;
        data.address := conn.address;
        checkCurrentAddress();
        connBox.items.add();
        if (flashOn = 'connection') and (conn.reply.mode <> HRM_CLOSE) then
          flash();
        runEventScript('connected');
      end;
    HE_DISCONNECTED:
      begin
        closeUploadingFile_partial();
        if leavedisconnectedconnectionsChk.checked then
        begin
          if assigned(data) then
            data.averageSpeed := safeDiv(conn.bytesSent,
              SECONDS * (now() - data.time));
          setupDownloadIcon(data); // remove the tray icon anyway
        end
        else
        begin
          data.deleting := TRUE;
          toDelete.add(data);
          with connBox.items do
            count := count - 1;
        end;
        runEventScript('disconnected');
        connBox.invalidate();
      end;
    HE_GOT:
      lastActivityTime := now();
    HE_SENT:
      begin
        if data.nextDloadScreenUpdate <= now() then
        begin
          data.nextDloadScreenUpdate := now() + DOWNLOAD_MIN_REFRESH_TIME;
          refreshConn(data);
          setupDownloadIcon(data);
        end;
        lastActivityTime := now();
      end;
    HE_POST_FILE:
      begin
        sessionSetup();
        data.downloadingWhat := DW_UNK;
        data.agent := getAgentID(conn);
        data.fileXferStart := now();
        f := findFilebyURL(decodeURL(conn.request.url));
        data.lastFile := f; // auto-freeing
        data.uploadSrc := optAnsi(Template.utf8, conn.post.filename);
        data.uploadFailed := '';
        if (f = NIL) or not accountAllowed(FA_UPLOAD, data, f) or
          not f.accessFor(data) then
          data.uploadFailed := if_(f = NIL, 'Folder not found.', 'Not allowed.')
        else
        begin
          closeUploadingFile();
          getUploadDestinationFileName();

          if complyUploadFilter() and canWriteFile() and canCreateFile() then
            saveFile(data.f^, conn.post.data);
          repaintTray();
        end;
        if data.uploadFailed > '' then
          logUploadFailed();
      end;
    HE_POST_MORE_FILE:
      if canWriteFile() then
        saveFile(data.f^, conn.post.data);
    HE_POST_END_FILE:
      begin
        // fill the record
        ur.fn := first(extractFileName(data.uploadDest), data.uploadSrc);
        if data.f = NIL then
          ur.size := -1
        else
          ur.size := filesize(data.f^);
        ur.speed := calcAverageSpeed(conn.bytesPostedLastItem);
        // custom scripts
        if assigned(data.f) then
          inc(uploadsLogged);
        closeUploadingFile();
        if data.uploadFailed = '' then
          data.uploadFailed := trim(runEventScript('upload completed'))
        else
          runEventScript('upload failed');
        ur.reason := data.uploadFailed;
        if data.uploadFailed > '' then
          deleteFile(data.uploadDest);
        // queue the record
        i := length(data.uploadResults);
        setLength(data.uploadResults, i + 1);
        data.uploadResults[i] := ur;

        refreshConn(data);
      end;
    HE_POST_VAR:
      data.postVars.add(conn.post.varname + '=' + conn.post.data);
    HE_POST_VARS:
      if conn.post.mode = PM_URLENCODED then
        urlToStrings(conn.post.data, data.postVars);
    // default case
  else
    refreshConn(data);
  end; // case
  if event in [HE_CONNECTED, HE_DISCONNECTED, HE_OPEN, HE_CLOSE, HE_REQUESTED,
    HE_POST_END, HE_LAST_BYTE_DONE] then
  begin
    repaintTray();
    updateTrayTip();
  end;
  doLog();
  if event = HE_LAST_BYTE_DONE then
    data.uploadResults := NIL;
end; // httpEvent

procedure findSimilarIP(fromIP: string);

  function howManySameNumbers(ip1, ip2: string): integer;
  var
    n1, n2: string;
  begin
    result := 0;
    while ip1 > '' do
    begin
      n1 := chop('.', ip1);
      n2 := chop('.', ip2);
      if n1 <> n2 then
        exit;
      inc(result);
    end;
  end; // howManySameNumbers

var
  chosen: string;
  i: integer;
  a: TStringDynArray;
begin
  if fromIP = '' then
    exit;
  if stringExists(fromIP, customIPs) then
  begin
    setDefaultIP(fromIP);
    exit;
  end;
  chosen := getIP();
  a := getIPs();
  for i := 0 to length(a) - 1 do
    if howManySameNumbers(chosen, fromIP) < howManySameNumbers(a[i], fromIP)
    then
      chosen := a[i];
  setDefaultIP(chosen);
end; // findSimilarIP

procedure setLimitOption(var variable: integer; newValue: integer;
  menuItem: TMenuItem; menuLabel: string);
begin
  if newValue < 0 then
    newValue := 0;
  variable := newValue;
  menuItem.Caption := format(menuLabel,
    [if_(newValue = 0, 'disabled', intToStr(newValue))]);
end; // setLimitOption

procedure setMaxIPs(v: integer);
begin
  setLimitOption(maxIPs, v, mainfrm.maxIPs1,
    'Max simultaneous addresses: %s ...')
end;

procedure setMaxIPsDLing(v: integer);
begin
  setLimitOption(maxIPsDLing, v, mainfrm.maxIPsDLing1,
    'Max simultaneous addresses downloading: %s ...')
end;

procedure setMaxConnections(v: integer);
begin
  setLimitOption(maxConnections, v, mainfrm.maxConnections1,
    'Max connections: %s ...')
end;

procedure setMaxConnectionsIP(v: integer);
begin
  setLimitOption(maxConnectionsIP, v, mainfrm.MaxconnectionsfromSingleaddress1,
    'Max connections from single address: %s ...')
end;

procedure setMaxDLs(v: integer);
begin
  setLimitOption(maxContempDLs, v, mainfrm.maxDLs1,
    'Max simultaneous downloads: %s ...')
end;

procedure setMaxDLsIP(v: integer);
begin
  setLimitOption(maxContempDLsIP, v, mainfrm.maxDLsIP1,
    'Max simultaneous downloads from single address: %s ...')
end;

procedure setAutoFingerprint(v: integer);
begin
  autoFingerprint := v;
  mainfrm.Createfingerprintonaddition1.Caption :=
    'Create fingerprint on addition' + if_(v = 0, ': disabled',
    format(' under %d KB', [v]));
end;

function loadFingerprint(fn: string): string;
var
  hasher: Thasher;
begin
  result := loadMD5for(fn);
  if result > '' then
    exit;

  hasher := Thasher.create();
  hasher.loadFrom(extractFilePath(fn));
  result := hasher.getHashFor(fn);
  hasher.free;
end; // loadFingerprint

procedure applyFilesBoxRatio();
begin
  if filesBoxRatio <= 0 then
    exit;
  mainfrm.filesPnl.Width := round(filesBoxRatio * mainfrm.clientWidth);
end; // applyFilesBoxRatio

procedure Tmainfrm.FormResize(Sender: Tobject);
begin
  urlBox.Width := urlToolbar.clientWidth - browseBtn.Width - copyBtn.Width;
  applyFilesBoxRatio();
end;

procedure checkIfOnlyCountersChanged();
begin
  if not VFSmodified and VFScounterMod then
    mainfrm.saveVFS(lastFileOpen)
end;

function checkVfsOnQuit(): boolean;
var
  s: string;
begin
  result := TRUE;
  if loadingVFS.disableAutosave then
    exit;
  checkIfOnlyCountersChanged();
  if not VFSmodified or mainfrm.quitWithoutAskingToSaveChk.checked then
    exit;
  if mainfrm.autosaveVFSchk.checked then
    mainfrm.saveVFS(lastFileOpen)
  else if windowsShuttingDown then
  begin
    s := lastFileOpen; // don't change this
    mainfrm.saveVFS(VFS_TEMP_FILE);
    lastFileOpen := s;
  end
  else
    case msgDlg('Your current file system is not saved.'#13'Save it?',
      MB_ICONQUESTION + if_(quitASAP, MB_YESNO, MB_YESNOCANCEL)) of
      IDYES:
        mainfrm.saveVFS(lastFileOpen);
      IDNO:
        ; // just go on
      IDCANCEL:
        result := FALSE;
    end;
end; // checkVfsOnQuit

procedure inputComment(f: Tfile);
const
  msg = 'Please insert a comment for "%s".' +
    #13'You should use HTML: <br> for break line.';
begin
  VFSmodified := inputqueryLong('Comment', format(msg, [f.name]), f.comment);
end; // inputComment

function Tmainfrm.addFile(f: Tfile; parent: TtreeNode = NIL;
  skipComment: boolean = FALSE): Tfile;
begin
  abortBtn.show();
  stopAddingItems := FALSE;
  try
    result := addFileRecur(f, parent);
  finally
    abortBtn.hide()
  end;
  if result = NIL then
    exit;
  if stopAddingItems then
    msgDlg('File addition was aborted.'#13'The list of files is incomplete.',
      MB_ICONWARNING);
  if assigned(parent) then
    parent.expanded := TRUE;
  filesbox.Selected := result.node;

  if skipComment or not autoCommentChk.checked then
    exit;
  application.restore();
  application.bringToFront();
  inputComment(f);
end; // addFile

function Tmainfrm.addFileRecur(f: Tfile; parent: TtreeNode = NIL): Tfile;
var
  n: TtreeNode;
  sr: TSearchRec;
  newF: Tfile;
  s: string;
begin
  result := f;
  if stopAddingItems then
    exit;

  if parent = NIL then
    parent := rootNode;

  if addingItemsCounter >= 0 then // counter enabled
  begin
    inc(addingItemsCounter);
    if addingItemsCounter and 15 = 0 then // step 16
    begin
      application.ProcessMessages();
      setStatusBarText(format('Adding item #%d', [addingItemsCounter]));
    end;
  end;

  // ensure the parent is a folder
  while assigned(parent) and assigned(parent.data) and not nodeToFile(parent)
    .isFolder() do
    parent := parent.parent;
  // test for duplicate. it often happens when you have a shortcut to a file.
  if existsNodeWithName(f.name, parent) then
  begin
    result := NIL;
    exit;
  end;

  if stopAddingItems then
    exit;

  n := filesbox.items.AddChild(parent, f.name);
  // stateIndex assignments are a workaround to a delphi bug
  n.stateIndex := 0;
  f.node := n;
  n.stateIndex := -1;
  n.data := f;
  f.setupImage();
  // autocreate fingerprint
  if f.isFile() and fingerprintsChk.checked and (autoFingerprint > 0) then
    try
      f.size := sizeOfFile(f.resource);
      if (autoFingerprint >= f.size div 1024) and
        (loadFingerprint(f.resource) = '') then
      begin
        s := createFingerprint(f.resource);
        if s > '' then
          saveFile(f.resource + '.md5', s);
      end;
    except
    end;

  if (f.resource = '') or not f.isVirtualFolder() then
    exit;
  // virtual folders must be run at addition-time
  if findfirst(f.resource + '\*', faAnyFile, sr) <> 0 then
    exit;
  try
    repeat
      if stopAddingItems then
        break;
      if (sr.name[1] = '.') or isFingerprintFile(sr.name) or
        isCommentFile(sr.name) then
        continue;
      newF := Tfile.create(f.resource + '\' + sr.name);
      if newF.isFolder() then
        include(newF.flags, FA_VIRTUAL);
      if addFileRecur(newF, n) = NIL then
        freeAndNIL(newF);
    until findNext(sr) <> 0;
  finally
    findClose(sr)
  end;
end; // addFileRecur

procedure Tmainfrm.filesBoxCollapsing(Sender: Tobject; node: TtreeNode;
  var AllowCollapse: boolean);
begin
  AllowCollapse := node.parent <> NIL;
end;

procedure Tmainfrm.Newlink1Click(Sender: Tobject);
var
  name: string;
begin
  name := getUniqueNodeName('New link', filesbox.Selected);
  addFile(Tfile.createLink(name), filesbox.Selected).node.Selected := TRUE;
  setURL1click(Sender);
end;

procedure Tmainfrm.newfolder1Click(Sender: Tobject);
var
  name: string;
begin
  name := getUniqueNodeName('New folder', filesbox.Selected);
  with addFile(Tfile.createVirtualFolder(name), filesbox.Selected).node do
  begin
    Selected := TRUE;
    editText();
  end;
end;

procedure Tmainfrm.filesBoxEditing(Sender: Tobject; node: TtreeNode;
  var AllowEdit: boolean);
begin
  if node = NIL then
    exit;
  { disable shortcuts, to be used in editbox. Shortcuts need to be re-activated,
    { but when the node text is left unchanged, no event is notified, so we got to
    { use timerEvent to do the work. }
  remove1.ShortCut := 0;
  Paste1.ShortCut := 0;

  AllowEdit := AllowEdit and not nodeToFile(node).isRoot()
end;

procedure Tmainfrm.filesBoxEdited(Sender: Tobject; node: TtreeNode;
  var s: String);
var
  f: Tfile;
begin
  f := node.data;
  s := trim(s); // mod by mars
  if f.name = s then
    exit;

  if f.isFileOrFolder() and not validFilename(s) or (s = '') or (pos('/', s) > 0)
  then
  begin
    s := node.text;
    msgDlg('Invalid filename', MB_ICONERROR);
    exit;
  end;

  if existsNodeWithName(s, node.parent) and
    (msgDlg(MSG_SAME_NAME, MB_ICONWARNING + MB_YESNO) <> IDYES) then
  begin
    s := node.text; // mod by mars
    exit;
  end;

  f.name := s;
  VFSmodified := TRUE;
  updateUrlBox();
end;

function setNilChildrenFrom(nodes: TtreeNodeDynArray; father: integer): integer;
var
  i: integer;
begin
  result := 0;
  for i := father + 1 to length(nodes) - 1 do
    if nodes[i].parent = nodes[father] then
    begin
      nodes[i] := NIL;
      inc(result);
    end;
end; // setNilChildrenFrom

procedure Tmainfrm.REMOVE(node: TtreeNode = NIL);
var
  i: integer;
  list: TtreeNodeDynArray;
  warn: boolean;
begin
  if assigned(node) then
  begin
    if node.parent = NIL then
      exit;
    if nodeIsLocked(node) then
    begin
      msgDlg(MSG_ITEM_LOCKED, MB_ICONERROR);
      exit;
    end;
    node.Delete();
    exit;
  end;

  i := filesbox.SelectionCount;
  if (i = 0) or (i = 1) and selectedFile.isRoot() then
    exit;
  if not deleteDontAskChk.checked and
    (msgDlg('Delete?', MB_ICONQUESTION + MB_YESNO) = IDNO) then
    exit;
  list := copySelection();
  // now proceed
  warn := FALSE;
  for i := 0 to length(list) - 1 do
    if assigned(list[i]) and assigned(list[i].parent) then
      if assigned(list[i].data) and nodeIsLocked(list[i]) then
        warn := TRUE
      else
      begin
        // avoid messing with children that will automatically be deleted as soon as the father is
        setNilChildrenFrom(list, i);
        list[i].Delete();
      end;

  if warn then
    msgDlg(MSG_SOME_LOCKED, MB_ICONWARNING);
end; // remove

procedure Tmainfrm.Remove1Click(Sender: Tobject);
begin
  // this method is bound to the DEL key also while a renaming is ongoing
  if not filesbox.IsEditing() then
    REMOVE()
end;

procedure Tmainfrm.startBtnClick(Sender: Tobject);
begin
  toggleServer()
end;

function Tmainfrm.pointedConnection(): TconnData;
var
  li: TlistItem;
begin
  result := NIL;
  with connBox.screenToClient(mouse.cursorPos) do
    li := connBox.getItemAt(x, y);
  if li = NIL then
    exit;
  result := conn2data(li);
end; // pointedConnection

function Tmainfrm.pointedFile(strict: boolean = TRUE): Tfile;
var
  n: TtreeNode;
  p: Tpoint;
begin
  result := NIL;
  p := filesbox.screenToClient(mouse.cursorPos);
  if strict and not(htOnItem in filesbox.getHitTestInfoAt(p.x, p.y)) then
    exit;
  n := filesbox.getNodeAt(p.x, p.y);
  if (n = NIL) or (n.data = NIL) then
    exit;
  result := n.data;
end; // pointedFile

procedure Tmainfrm.updateUrlBox();
var
  f: Tfile;
begin
  if quitting then
    exit;
  if selectedFile = NIL then
    f := rootFile
  else
    f := selectedFile;

  if f = NIL then
    urlBox.text := ''
  else
    urlBox.text := f.fullURL()
end; // updateUrlBox

procedure Tmainfrm.filesBoxChange(Sender: Tobject; node: TtreeNode);
begin
  if filesbox.SelectionCount = 0 then
    selectedFile := NIL
  else
    selectedFile := filesbox.selections[0].data;
  updateUrlBox()
end;

function Tmainfrm.selectedConnection(): TconnData;
begin
  if connBox.Selected = NIL then
    result := NIL
  else
    result := conn2data(connBox.Selected)
end;

procedure Tmainfrm.setLogToolbar(v: boolean);
begin
  expandedPnl.visible := v;
  collapsedPnl.visible := not v;
end; // setLogToolbar

procedure Tmainfrm.Kickconnection1Click(Sender: Tobject);
var
  cd: TconnData;
begin
  cd := selectedConnection();
  if cd = NIL then
    exit;
  cd.disconnect('kicked');
end;

procedure Tmainfrm.Kickallconnections1Click(Sender: Tobject);
begin
  kickByIP('*')
end;

procedure Tmainfrm.KickIPaddress1Click(Sender: Tobject);
var
  cd: TconnData;
begin
  cd := selectedConnection();
  if cd = NIL then
    exit;
  kickByIP(cd.address);
end;

procedure setAutosave(var rec: Tautosave; v: integer);
begin
  rec.every := v;
  if assigned(rec.menu) then
    rec.menu.Caption := 'Auto save every: ' + if_(v = 0, 'disabled',
      intToStr(v) + ' seconds');
end; // setAutosave

procedure setSpeedLimitIP(v: real);
var
  i, vi: integer;
begin
  speedLimitIP := v;
  if v < 0 then
    vi := MAXINT
  else
    vi := round(v * 1000);
  for i := 0 to ip2obj.count - 1 do
    with ip2obj.Objects[i] as TperIp do
      if not customizedLimiter then
        limiter.maxSpeed := vi;
  mainfrm.Speedlimitforsingleaddress1.Caption :=
    'Speed limit for single address: ' + if_(v < 0, 'disabled',
    floatToStr(v) + ' KB/s');
end; // setSpeedLimitIP

procedure setSpeedLimit(v: real);
begin
  speedLimit := v;
  if v < 0 then
    globalLimiter.maxSpeed := MAXINT
  else
    globalLimiter.maxSpeed := round(v * 1000);
  mainfrm.speedLimit1.Caption := 'Speed limit: ' + if_(v < 0, 'disabled',
    floatToStr(v) + ' KB/s');
end; // setSpeedLimit

procedure autosaveClick(var rec: Tautosave; name: string);
const
  msg = 'Auto-save %s.' + #13'Specify in seconds.' +
    #13'Leave blank to disable.';
  MSG_MIN = 'We don''t accept less than %d';
var
  s: string;
  v: integer;
begin
  if rec.every <= 0 then
    s := ''
  else
    s := intToStr(rec.every);
  repeat
    if not InputQuery('Auto-save ' + name, format(msg, [name]), s) then
      exit;
    s := trim(s);
    if s = '' then
    begin
      setAutosave(rec, 0);
      break;
    end
    else
      try
        v := strToInt(s);
        if v >= rec.minimum then
        begin
          setAutosave(rec, v);
          break;
        end;
        msgDlg(format(MSG_MIN, [rec.minimum]), MB_ICONERROR);
      except
        msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
      end;
  until FALSE;
end; // autosaveClick

// change port and test it working. Restore if not working.
function changePort(newVal: string): boolean;
var
  act: boolean;
  was: string;
begin
  result := TRUE;
  act := srv.active;
  was := port;
  port := newVal;
  if act and (newVal = srv.port) then
    exit;
  stopServer();
  if startServer() then
  begin
    if not act then
      stopServer(); // restore
    exit;
  end;
  result := FALSE;
  port := was;
  if act then
    startServer();
end; // changePort

function Tmainfrm.getCfg(exclude: string = ''): string;
type
  Tencoding = (E_PLAIN, E_B64, E_ZIP);

  function encode(s: string; encoding: Tencoding): string;
  begin
    case encoding of
      E_PLAIN:
        result := s;
      E_B64:
        result := base64encode(s);
      E_ZIP:
        begin
          result := zCompressStr(s, zcMax);
          if length(result) > round(0.95 * length(s)) then
            result := s;
          result := base64encode(result);
        end;
    end;
  end;

  function accountsToStr(): string;
  var
    i: integer;
    a: Paccount;

    function prop(name, value: string; encoding: Tencoding = E_PLAIN): string;
    begin
      result := if_(value > '', '|' + name + ':' + encode(value, encoding))
    end;

  begin
    result := '';
    for i := 0 to length(accounts) - 1 do
    begin
      a := @accounts[i];
      result := result + prop('login', a.user + ':' + a.pwd, E_B64) +
        prop('enabled', yesno[a.enabled]) + prop('group', yesno[a.group]) +
        prop('no-limits', yesno[a.noLimits]) + prop('redir', a.redir) +
        prop('link', join(':', a.link)) + prop('notes', a.notes, E_ZIP) + ';';
    end;
  end; // accountsToStr

  function banlistToStr(): string;
  var
    i: integer;
  begin
    result := '';
    for i := 0 to length(banlist) - 1 do
      result := result + banlist[i].ip + '#' + xtpl(banlist[i].comment,
        ['|', '\$pipe']) + '|';
  end;

  function connColumnsToStr(): string;
  var
    i: integer;
  begin
    result := '';
    for i := 0 to connBox.columns.count - 1 do
      with connBox.columns.items[i] do
        result := result + format('%s;%d|', [Caption, Width]);
  end; // connColumnsToStr

var
  iconMasksStr, userIconMasks: string;

  function iconMasksToStr(): string;
  var
    i, j: integer;
  begin
    result := '';
    for i := 0 to length(iconMasks) - 1 do
    begin
      j := idx_img2ico(iconMasks[i].int);
      if j >= USER_ICON_MASKS_OFS then
        userIconMasks := userIconMasks + format('%d:%s|',
          [j, encode(pic2str(j), E_ZIP)]);
      result := result + format('%s|%d||', [iconMasks[i].str, j]);
    end;
  end; // iconMasksToStr

  function fontToStr(f: Tfont): string;
  begin
    result := if_(fsBold in f.Style, 'B') + if_(fsItalic in f.Style, 'I') +
      if_(fsUnderline in f.Style, 'U') + if_(fsStrikeOut in f.Style, 'S');
    result := format('%s|%d|%s|%s',
      [f.name, f.size, colorToString(f.color), result]);
  end; // fontToStr

begin
  userIconMasks := '';
  iconMasksStr := iconMasksToStr();
  result := 'HFS ' + HFS.Consts.VERSION + ' - Build #' + VERSION_BUILD + CRLF + 'active=' +
    yesno[srv.active] + CRLF + 'only-1-instance=' +
    yesno[only1instanceChk.checked] + CRLF + 'window=' +
    rectToStr(lastWindowRect) + CRLF + 'window-max=' +
    yesno[windowState = wsMaximized] + CRLF + 'easy=' + yesno[easyMode] + CRLF +
    'port=' + port + CRLF + 'files-box-ratio=' + floatToStr(filesBoxRatio) +
    CRLF + 'log-max-lines=' + intToStr(logMaxLines) + CRLF + 'log-read-only=' +
    yesno[logbox.readonly] + CRLF + 'log-file-name=' + logFile.filename + CRLF +
    'log-font-name=' + logFontName + CRLF + 'log-font-size=' +
    intToStr(logFontSize) + CRLF + 'log-date=' + yesno[logDateChk.checked] +
    CRLF + 'log-time=' + yesno[logTimeChk.checked] + CRLF + 'log-to-screen=' +
    yesno[logOnVideoChk.checked] + CRLF + 'log-only-served=' +
    yesno[logOnlyServedChk.checked] + CRLF + 'log-server-start=' +
    yesno[logServerstartChk.checked] + CRLF + 'log-server-stop=' +
    yesno[logServerstopChk.checked] + CRLF + 'log-connections=' +
    yesno[logconnectionsChk.checked] + CRLF + 'log-disconnections=' +
    yesno[logDisconnectionsChk.checked] + CRLF + 'log-bytes-sent=' +
    yesno[logBytessentChk.checked] + CRLF + 'log-bytes-received=' +
    yesno[logBytesreceivedChk.checked] + CRLF + 'log-replies=' +
    yesno[logRepliesChk.checked] + CRLF + 'log-requests=' +
    yesno[logRequestsChk.checked] + CRLF + 'log-uploads=' +
    yesno[logUploadsChk.checked] + CRLF + 'log-deletions=' +
    yesno[logDeletionsChk.checked] + CRLF + 'log-full-downloads=' +
    yesno[logFulldownloadsChk.checked] + CRLF + 'log-dump-request=' +
    yesno[dumprequestsChk.checked] + CRLF + 'log-browsing=' +
    yesno[logBrowsingChk.checked] + CRLF + 'log-icons=' +
    yesno[logIconsChk.checked] + CRLF + 'log-progress=' +
    yesno[logProgressChk.checked] + CRLF + 'log-banned=' +
    yesno[logBannedChk.checked] + CRLF + 'log-others=' +
    yesno[logOtherEventsChk.checked] + CRLF + 'log-file-tabbed=' +
    yesno[tabOnLogFileChk.checked] + CRLF + 'log-apache-format=' +
    logFile.apacheFormat + CRLF + 'tpl-file=' + tplFilename + CRLF +
    'tpl-editor=' + tplEditor + CRLF + 'delete-dont-ask=' +
    yesno[deleteDontAskChk.checked] + CRLF + 'free-login=' +
    yesno[freeLoginChk.checked] + CRLF + 'confirm-exit=' +
    yesno[confirmexitChk.checked] + CRLF + 'keep-bak-updating=' +
    yesno[keepBakUpdatingChk.checked] + CRLF + 'include-pwd-in-pages=' +
    yesno[pwdInPagesChk.checked] + CRLF + 'ip=' + defaultIP + CRLF +
    'custom-ip=' + join(';', customIPs) + CRLF + 'listen-on=' + listenOn + CRLF
    + 'external-ip-server=' + customIPservice + CRLF + 'dynamic-dns-updater=' +
    base64encode(dyndns.url) + CRLF + 'dynamic-dns-user=' + dyndns.user + CRLF +
    'dynamic-dns-host=' + dyndns.host + CRLF + 'search-better-ip=' +
    yesno[searchbetteripChk.checked] + CRLF + 'start-minimized=' +
    yesno[startMinimizedChk.checked] + CRLF + 'connections-height=' +
    intToStr(lastGoodConnHeight) + CRLF + 'files-stay-flagged-for-minutes=' +
    intToStr(filesStayFlaggedForMinutes) + CRLF + 'auto-save-vfs=' +
    yesno[autosaveVFSchk.checked] + CRLF + 'folders-before=' +
    yesno[foldersbeforeChk.checked] + CRLF + 'links-before=' +
    yesno[linksBeforeChk.checked] + CRLF + 'use-comment-as-realm=' +
    yesno[useCommentAsRealmChk.checked] + CRLF + 'getright-template=' +
    yesno[DMbrowserTplChk.checked] + CRLF + 'auto-save-options=' +
    yesno[autosaveoptionsChk.checked] + CRLF + 'dont-include-port-in-url=' +
    yesno[noPortInUrlChk.checked] + CRLF + 'persistent-connections=' +
    yesno[persistentconnectionsChk.checked] + CRLF + 'modal-options=' +
    yesno[modalOptionsChk.checked] + CRLF + 'beep-on-flash=' +
    yesno[beepChk.checked] + CRLF + 'prevent-leeching=' +
    yesno[preventLeechingChk.checked] + CRLF + 'delete-partial-uploads=' +
    yesno[deletePartialUploadsChk.checked] + CRLF + 'rename-partial-uploads=' +
    renamePartialUploads + CRLF + 'enable-macros=' +
    yesno[enableMacrosChk.checked] + CRLF + 'use-system-icons=' +
    yesno[useSystemIconsChk.checked] + CRLF + 'minimize-to-tray=' +
    yesno[MinimizetotrayChk.checked] + CRLF + 'tray-icon-for-each-download=' +
    yesno[trayfordownloadChk.checked] + CRLF + 'show-main-tray-icon=' +
    yesno[showmaintrayiconChk.checked] + CRLF + 'always-on-top=' +
    yesno[alwaysontopChk.checked] + CRLF + 'quit-dont-ask=' +
    yesno[quitWithoutAskingToSaveChk.checked] + CRLF + 'support-descript.ion=' +
    yesno[supportDescriptionChk.checked] + CRLF + 'oem-descript.ion=' +
    yesno[oemForIonChk.checked] + CRLF + 'oem-tar=' + yesno[oemTarChk.checked] +
    CRLF + 'enable-fingerprints=' + yesno[fingerprintsChk.checked] + CRLF +
    'save-fingerprints=' + yesno[saveNewFingerprintsChk.checked] + CRLF +
    'auto-fingerprint=' + intToStr(autoFingerprint) + CRLF + 'encode-pwd-url=' +
    yesno[encodePwdUrlChk.checked] + CRLF + 'stop-spiders=' +
    yesno[stopSpidersChk.checked] + CRLF + 'backup-saving=' +
    yesno[backupSavingChk.checked] + CRLF + 'recursive-listing=' +
    yesno[recursiveListingChk.checked] + CRLF + 'send-hfs-identifier=' +
    yesno[sendHFSidentifierChk.checked] + CRLF + 'list-hidden-files=' +
    yesno[listfileswithHiddenAttributeChk.checked] + CRLF + 'list-system-files='
    + yesno[listfileswithsystemattributeChk.checked] + CRLF +
    'list-protected-items=' + yesno[hideProtectedItemsChk.checked] + CRLF +
    'enable-no-default=' + yesno[enableNoDefaultChk.checked] + CRLF +
    'browse-localhost=' + yesno[browseUsingLocalhostChk.checked] + CRLF +
    'add-folder-default=' + addFolderDefault + CRLF + 'default-sorting=' +
    defSorting + CRLF + 'last-dialog-folder=' + lastDialogFolder + CRLF +
    'auto-save-vfs-every=' + intToStr(autosaveVFS.every) + CRLF +
    'last-update-check=' + floatToStr(lastUpdateCheck) + CRLF +
    'allowed-referer=' + allowedReferer + CRLF + 'forwarded-mask=' +
    forwardedMask + CRLF + 'tray-shows=' + trayShows + CRLF + 'tray-message=' +
    escapeNL(trayMsg) + CRLF + 'speed-limit=' + floatToStr(speedLimit) + CRLF +
    'speed-limit-ip=' + floatToStr(speedLimitIP) + CRLF + 'max-ips=' +
    intToStr(maxIPs) + CRLF + 'max-ips-downloading=' + intToStr(maxIPsDLing) +
    CRLF + 'max-connections=' + intToStr(maxConnections) + CRLF +
    'max-connections-by-ip=' + intToStr(maxConnectionsIP) + CRLF +
    'max-contemporary-dls=' + intToStr(maxContempDLs) + CRLF +
    'max-contemporary-dls-ip=' + intToStr(maxContempDLsIP) + CRLF +
    'login-realm=' + loginRealm + CRLF + 'open-in-browser=' + openInBrowser +
    CRLF + 'flash-on=' + flashOn + CRLF + 'graph-rate=' + intToStr(graph.rate) +
    CRLF + 'graph-size=' + intToStr(graph.size) + CRLF + 'graph-visible=' +
    yesno[graphBox.visible] + CRLF + 'no-download-timeout=' +
    intToStr(noDownloadTimeout) + CRLF + 'connections-timeout=' +
    intToStr(connectionsInactivityTimeout) + CRLF + 'no-reply-ban=' +
    yesno[noReplyBan] + CRLF + 'ban-list=' + banlistToStr() + CRLF +
    'add-to-folder=' + addToFolder + CRLF + 'last-file-open=' + lastFileOpen +
    CRLF + 'reload-on-startup=' + yesno[reloadonstartupChk.checked] + CRLF +
    'https-url=' + yesno[httpsUrlsChk.checked] + CRLF +
    'find-external-on-startup=' + yesno[findExtOnStartupChk.checked] + CRLF +
    'encode-non-ascii=' + yesno[encodenonasciiChk.checked] + CRLF +
    'encode-spaces=' + yesno[encodeSpacesChk.checked] + CRLF + 'mime-types=' +
    join('|', mimeTypes) + CRLF + 'in-browser-if-mime=' + yesno[inBrowserIfMIME]
    + CRLF + 'icon-masks=' + iconMasksStr + CRLF + 'icon-masks-user-images=' +
    userIconMasks + CRLF + 'address2name=' + join('|', address2name) + CRLF +
    'recent-files=' + join('|', recentFiles) + CRLF + 'trusted-files=' +
    join('|', trustedFiles) + CRLF + 'leave-disconnected-connections=' +
    yesno[leavedisconnectedconnectionsChk.checked] + CRLF + 'accounts=' +
    accountsToStr() + CRLF + 'account-notes-wrap=' +
    yesno[optionsFrm.notesWrapChk.checked] + CRLF + 'tray-instead-of-quit=' +
    yesno[trayInsteadOfQuitChk.checked] + CRLF + 'compressed-browsing=' +
    yesno[compressedbrowsingChk.checked] + CRLF + 'use-iso-date-format=' +
    yesno[useISOdateChk.checked] + CRLF + 'hints4newcomers=' +
    yesno[HintsfornewcomersChk.checked] + CRLF + 'save-totals=' +
    yesno[saveTotalsChk.checked] + CRLF + 'log-toolbar-expanded=' +
    yesno[mainfrm.expandedPnl.visible] + CRLF + 'number-files-on-upload=' +
    yesno[numberFilesOnUploadChk.checked] + CRLF + 'do-not-log-address=' +
    dontLogAddressMask + CRLF + 'last-external-address=' + dyndns.lastIP + CRLF
    + 'min-disk-space=' + intToStr(minDiskSpace) + CRLF + 'out-total=' +
    intToStr(outTotalOfs + srv.bytesSent) + CRLF + 'in-total=' +
    intToStr(inTotalOfs + srv.bytesReceived) + CRLF + 'hits-total=' +
    intToStr(hitsLogged) + CRLF + 'downloads-total=' + intToStr(downloadsLogged)
    + CRLF + 'upload-total=' + intToStr(uploadsLogged) + CRLF +
    'many-items-warning=' + yesno[warnManyItems] + CRLF +
    'load-single-comment-files=' + yesno[loadSingleCommentsChk.checked] + CRLF +
    'copy-url-on-start=' + yesno[autocopyURLonstartChk.checked] + CRLF +
    'connections-columns=' + connColumnsToStr() + CRLF + 'auto-comment=' +
    yesno[autoCommentChk.checked] + CRLF + 'update-daily=' +
    yesno[updateDailyChk.checked] + CRLF + 'delayed-update=' +
    yesno[delayUpdateChk.checked] + CRLF + 'tester-updates=' +
    yesno[testerUpdatesChk.checked] + CRLF + 'copy-url-on-addition=' +
    yesno[AutocopyURLonadditionChk.checked] + CRLF + 'ip-services=' +
    join(';', IPservices) + CRLF + 'ip-services-time=' +
    floatToStr(IPservicesTime) + CRLF + 'update-automatically=' +
    yesno[updateAutomaticallyChk.checked] + CRLF + 'prevent-standby=' +
    yesno[preventStandbyChk.checked] + CRLF;

  if ipsEverConnected.count < IPS_THRESHOLD then
    result := result + 'ips-ever-connected=' +
      ipsEverConnected.DelimitedText + CRLF;

  if exclude = '' then
    exit;
  exclude := stringReplace(exclude, '.', '[^=]', [rfReplaceAll]);
  // optimization: since we are searching for keys, characters can't be "="
  result := reReplace(result, '^(' + exclude + ')=.*$', '');
end; // getCfg

// this is to keep the "hashed" version updated
var
  lastUcCFG: Tdatetime;

procedure updateCurrentCFG();
var
  s: string;
begin
  if mainfrm = NIL then
    exit;

  // not faster
  if lastUcCFG + 5 / SECONDS > now() then
    exit;
  lastUcCFG := now();

  s := mainfrm.getCfg('.*-total');
  // these will change often and are of no interest, so we ignore them as an optimization
  if s = currentCFG then
    exit;

  if (currentCFG > '') // first time, it's not an update, it's an initialization
    and mainfrm.autosaveoptionsChk.checked then
    mainfrm.saveCFG();

  currentCFG := s;
  currentCFGhashed.text := s; // re-parse
end; // updateCurrentCFG

function Tmainfrm.setCfg(cfg: string; alreadyStarted: boolean): boolean;
const
  MSG_BAN = 'Your ban configuration may have been screwed up.' +
    #13'Please verify it.';
var
  l, savedip, build: string;
  warnings: TStringDynArray;
  userIconOfs: integer;

  function yes(s: string = ''): boolean;
  begin
    result := if_(s > '', s, l) = 'yes'
  end;

  function int(): int64;
  begin
    if not tryStrToInt64(l, result) then
      result := 0
  end;

  function real(): Tdatetime;
  begin
    try
      result := strToFloat(l)
    except
      result := 0
    end
  end;

  procedure loadBanlist(s: string);
  var
    p: string;
    i: integer;
  begin
    { old versions wrongly used ; as ban-record separator, while it was already
      { used as address separator }
    if (build < '018') and (pos(';', s) > 0) then
    begin
      s := xtpl(s, [';', '|']);
      addString(MSG_BAN, warnings);
    end;
    setLength(banlist, 0);
    i := 0;
    while s > '' do
    begin
      p := chop('|', s);
      if p = '' then
        continue;
      setLength(banlist, i + 1);
      banlist[i].comment := xtpl(p, ['\$pipe', '|']); // unescape
      banlist[i].ip := chop('#', banlist[i].comment);
      inc(i);
    end;
  end; // loadBanlist

  function unzip(s: string): string;
  begin
    result := base64decode(s);
    try
      result := ZDecompressStr(result);
    except
    end;
  end; // unzip

  procedure strToAccounts();
  var
    s, t, p: string;
    i: integer;
    a: Paccount;
  begin
    accounts := NIL;
    while l > '' do
    begin
      // accounts are separated by semicolons
      s := chop(';', l);
      if s = '' then
        continue;
      i := length(accounts);
      setLength(accounts, i + 1);
      a := @accounts[i];
      a.enabled := TRUE; // by default
      while s > '' do
      begin
        // account properties are separated by pipes
        t := chop('|', s);
        p := chop(':', t); // get property name
        if p = '' then
          continue;
        if p = 'login' then
        begin
          if not anycharIn(':', t) then
            t := base64decode(t);
          a.user := chop(':', t);
          a.pwd := t;
        end;
        if p = 'enabled' then
          a.enabled := yes(t);
        if p = 'no-limits' then
          a.noLimits := yes(t);
        if p = 'group' then
          a.group := yes(t);
        if p = 'redir' then
          a.redir := t;
        if p = 'link' then
          a.link := split(':', t);
        if p = 'notes' then
          a.notes := unzip(t);
      end;
    end;
  end; // strToAccounts

  procedure strToIconmasks();
  var
    i: integer;
  begin
    while l > '' do
    begin
      i := length(iconMasks);
      setLength(iconMasks, i + 1);
      iconMasks[i].str := chop('|', l);
      iconMasks[i].int := StrToIntDef(chop('||', l), 0);
    end;
  end; // strToIconmasks

  procedure readUserIconMasks();
  var
    i, iFrom, iTo: integer;
  begin
    userIconOfs := images.count;
    while l > '' do
    begin
      iFrom := StrToIntDef(chop(':', l), -1);
      iTo := str2pic(unzip(chop('|', l)));
      for i := 0 to length(iconMasks) - 1 do
        if iconMasks[i].int = iFrom then
          iconMasks[i].int := iTo;
    end;
  end; // readUserIconmasks

  procedure strToFont(f: Tfont);
  begin
    f.name := chop('|', l);
    f.size := StrToIntDef(chop('|', l), f.size);
    f.color := StringToColor(chop('|', l));
    f.Style := [];
    if pos('B', l) > 0 then
      f.Style := f.Style + [fsBold];
    if pos('U', l) > 0 then
      f.Style := f.Style + [fsUnderline];
    if pos('I', l) > 0 then
      f.Style := f.Style + [fsItalic];
    if pos('S', l) > 0 then
      f.Style := f.Style + [fsStrikeOut];
  end; // strToFont

  procedure addMissingMimeTypes();
  var
    i: integer;
  begin
    // add missing default mime types
    i := length(DEFAULT_MIME_TYPES);
    while i > 0 do
    begin
      dec(i, 2);
      if stringExists(DEFAULT_MIME_TYPES[i], mimeTypes) then
        continue;
      // add the missing pair at the beginning
      addArray(mimeTypes, DEFAULT_MIME_TYPES, 0, i, 2);
    end;
  end;

const
  BOOL2WS: array [boolean] of TWindowState = (wsNormal, wsMaximized);
var
  i: integer;
  h: string;
  activateServer: boolean;
begin
  result := FALSE;
  if cfg = '' then
    exit;

  // prior to build #230, this header was required
  if ansiStartsStr('HFS ', cfg) then
  begin
    l := chop(CRLF, cfg);
    chop(' - Build #', l);
    build := l;
  end
  else
    build := VERSION_BUILD;

  warnings := NIL;
  if alreadyStarted then
    activateServer := srv.active
  else
    activateServer := TRUE;

  while cfg > '' do
  begin
    l := chop(CRLF, cfg);
    h := chop('=', l);
    try
      if h = 'banned-ips' then
        h := 'ban-list';
      if h = 'user-mime-types' then
        h := 'mime-types';
      // user-mime-types was an experiment made in build #258..260
      if h = 'save-in-out-totals' then
        h := 'save-totals';

      if h = 'active' then
        activateServer := yes;
      if (h = 'window') and (l <> '0,0,0,0') then
      begin
        lastWindowRect := strToRect(l);
        boundsRect := lastWindowRect;
      end;
      if h = 'window-max' then
        windowState := BOOL2WS[yes];
      if h = 'port' then
        if srv.active then
          changePort(l)
        else
          port := l;
      if h = 'ip' then
        savedip := l;
      if h = 'custom-ip' then
        customIPs := split(';', l);
      if h = 'listen-on' then
        listenOn := l;
      if h = 'dynamic-dns-updater' then
        dyndns.url := base64decode(l);
      if h = 'dynamic-dns-user' then
        dyndns.user := l;
      if h = 'dynamic-dns-host' then
        dyndns.host := l;
      if h = 'login-realm' then
        loginRealm := l;
      if h = 'easy' then
        setEasyMode(yes);
      if h = 'keep-bak-updating' then
        keepBakUpdatingChk.checked := yes;
      if h = 'encode-non-ascii' then
        encodenonasciiChk.checked := yes;
      if h = 'encode-spaces' then
        encodeSpacesChk.checked := yes;
      if h = 'search-better-ip' then
        searchbetteripChk.checked := yes;
      if h = 'start-minimized' then
        startMinimizedChk.checked := yes;
      if h = 'files-box-ratio' then
        filesBoxRatio := real;
      if h = 'log-max-lines' then
        logMaxLines := int;
      if h = 'log-file-name' then
        logFile.filename := l;
      if h = 'log-font-name' then
        logFontName := l;
      if h = 'log-font-size' then
        logFontSize := int;
      if h = 'log-date' then
        logDateChk.checked := yes;
      if h = 'log-time' then
        logTimeChk.checked := yes;
      if h = 'log-read-only' then
        logbox.readonly := yes;
      if h = 'log-browsing' then
        logBrowsingChk.checked := yes;
      if h = 'log-icons' then
        logIconsChk.checked := yes;
      if h = 'log-progress' then
        logProgressChk.checked := yes;
      if h = 'log-banned' then
        logBannedChk.checked := yes;
      if h = 'log-others' then
        logOtherEventsChk.checked := yes;
      if h = 'log-dump-request' then
        dumprequestsChk.checked := yes;
      if h = 'log-server-start' then
        logServerstartChk.checked := yes;
      if h = 'log-server-stop' then
        logServerstopChk.checked := yes;
      if h = 'log-connections' then
        logconnectionsChk.checked := yes;
      if h = 'log-disconnections' then
        logDisconnectionsChk.checked := yes;
      if h = 'log-bytes-sent' then
        logBytessentChk.checked := yes;
      if h = 'log-bytes-received' then
        logBytesreceivedChk.checked := yes;
      if h = 'log-replies' then
        logRepliesChk.checked := yes;
      if h = 'log-requests' then
        logRequestsChk.checked := yes;
      if h = 'log-uploads' then
        logUploadsChk.checked := yes;
      if h = 'log-deletions' then
        logDeletionsChk.checked := yes;
      if h = 'log-full-downloads' then
        logFulldownloadsChk.checked := yes;
      if h = 'log-apache-format' then
        logFile.apacheFormat := l;
      if h = 'log-only-served' then
        logOnlyServedChk.checked := yes;
      if h = 'log-to-screen' then
        logOnVideoChk.checked := yes;
      if h = 'log-file-tabbed' then
        tabOnLogFileChk.checked := yes;
      if h = 'confirm-exit' then
        confirmexitChk.checked := yes;
      if h = 'backup-saving' then
        backupSavingChk.checked := yes;
      if h = 'connections-height' then
        lastGoodConnHeight := int;
      if h = 'files-stay-flagged-for-minutes' then
        filesStayFlaggedForMinutes := int;
      if h = 'folders-before' then
        foldersbeforeChk.checked := yes;
      if h = 'include-pwd-in-pages' then
        pwdInPagesChk.checked := yes;
      if h = 'minimize-to-tray' then
        MinimizetotrayChk.checked := yes;
      if h = 'prevent-standby' then
        preventStandbyChk.checked := yes;
      if h = 'use-system-icons' then
        useSystemIconsChk.checked := yes;
      if h = 'quit-dont-ask' then
        quitWithoutAskingToSaveChk.checked := yes;
      if h = 'auto-save-options' then
        autosaveoptionsChk.checked := yes;
      if h = 'use-comment-as-realm' then
        useCommentAsRealmChk.checked := yes;
      if h = 'persistent-connections' then
        persistentconnectionsChk.checked := yes;
      if h = 'show-main-tray-icon' then
        showmaintrayiconChk.checked := yes;
      if h = 'delete-dont-ask' then
        deleteDontAskChk.checked := yes;
      if h = 'tray-icon-for-each-download' then
        trayfordownloadChk.checked := yes;
      if h = 'copy-url-on-addition' then
        AutocopyURLonadditionChk.checked := yes;
      if h = 'copy-url-on-start' then
        autocopyURLonstartChk.checked := yes;
      if h = 'enable-macros' then
        enableMacrosChk.checked := yes;
      if h = 'update-daily' then
        updateDailyChk.checked := yes;
      if h = 'tray-instead-of-quit' then
        trayInsteadOfQuitChk.checked := yes;
      if h = 'modal-options' then
        modalOptionsChk.checked := yes;
      if h = 'beep-on-flash' then
        beepChk.checked := yes;
      if h = 'prevent-leeching' then
        preventLeechingChk.checked := yes;
      if h = 'list-hidden-files' then
        listfileswithHiddenAttributeChk.checked := yes;
      if h = 'list-system-files' then
        listfileswithsystemattributeChk.checked := yes;
      if h = 'list-protected-items' then
        hideProtectedItemsChk.checked := yes;
      if h = 'always-on-top' then
        alwaysontopChk.checked := yes;
      if h = 'support-descript.ion' then
        supportDescriptionChk.checked := yes;
      if h = 'oem-descript.ion' then
        oemForIonChk.checked := yes;
      if h = 'oem-tar' then
        oemTarChk.checked := yes;
      if h = 'free-login' then
        freeLoginChk.checked := yes;
      if h = 'https-url' then
        httpsUrlsChk.checked := yes;
      if h = 'enable-fingerprints' then
        fingerprintsChk.checked := yes;
      if h = 'save-fingerprints' then
        saveNewFingerprintsChk.checked := yes;
      if h = 'auto-fingerprint' then
        setAutoFingerprint(int);
      if h = 'encode-pwd-url' then
        encodePwdUrlChk.checked := yes;
      if h = 'log-toolbar-expanded' then
        setLogToolbar(yes);
      if h = 'last-update-check' then
        lastUpdateCheck := real;
      if h = 'recursive-listing' then
        recursiveListingChk.checked := yes;
      if h = 'enable-no-default' then
        enableNoDefaultChk.checked := yes;
      if h = 'browse-localhost' then
        browseUsingLocalhostChk.checked := yes;
      if h = 'tpl-file' then
        tplFilename := l;
      if h = 'tpl-editor' then
        tplEditor := l;
      if h = 'add-folder-default' then
        addFolderDefault := l;
      if h = 'default-sorting' then
        defSorting := l;
      if h = 'last-dialog-folder' then
        lastDialogFolder := l;
      if h = 'send-hfs-identifier' then
        sendHFSidentifierChk.checked := yes;
      if h = 'auto-save-vfs' then
        autosaveVFSchk.checked := yes;
      if h = 'add-to-folder' then
        addToFolder := l;
      if h = 'getright-template' then
        DMbrowserTplChk.checked := yes;
      if h = 'leave-disconnected-connections' then
        leavedisconnectedconnectionsChk.checked := yes;
      if h = 'speed-limit' then
        setSpeedLimit(real);
      if h = 'speed-limit-ip' then
        setSpeedLimitIP(real);
      if h = 'no-download-timeout' then
        setNoDownloadTimeout(int);
      if h = 'connections-timeout' then
        connectionsInactivityTimeout := int;
      if h = 'max-ips' then
        setMaxIPs(int);
      if h = 'max-ips-downloading' then
        setMaxIPsDLing(int);
      if h = 'max-connections' then
        setMaxConnections(int);
      if h = 'max-connections-by-ip' then
        setMaxConnectionsIP(int);
      if h = 'max-contemporary-dls' then
        setMaxDLs(int);
      if h = 'max-contemporary-dls-ip' then
        setMaxDLsIP(int);
      if h = 'tray-message' then
        trayMsg := xtpl(unescapeNL(l), [CRLF, trayNL]);
      if h = 'ban-list' then
        loadBanlist(l);
      if h = 'no-reply-ban' then
        noReplyBan := yes;
      if h = 'save-totals' then
        saveTotalsChk.checked := yes;
      if h = 'allowed-referer' then
        allowedReferer := l;
      if h = 'open-in-browser' then
        openInBrowser := l;
      if h = 'last-file-open' then
        lastFileOpen := l;
      if h = 'reload-on-startup' then
        reloadonstartupChk.checked := yes;
      if h = 'stop-spiders' then
        stopSpidersChk.checked := yes;
      if h = 'find-external-on-startup' then
        findExtOnStartupChk.checked := yes;
      if h = 'dont-include-port-in-url' then
        noPortInUrlChk.checked := yes;
      if h = 'tray-shows' then
        trayShows := l;
      if h = 'auto-save-vfs-every' then
        setAutosave(autosaveVFS, int);
      if h = 'external-ip-server' then
        customIPservice := l;
      if h = 'only-1-instance' then
        only1instanceChk.checked := yes;
      if h = 'graph-rate' then
        setGraphRate(int);
      if h = 'graph-size' then
        graph.size := int;
      if h = 'forwarded-mask' then
        forwardedMask := l;
      if h = 'delete-partial-uploads' then
        deletePartialUploadsChk.checked := yes;
      if h = 'rename-partial-uploads' then
        renamePartialUploads := l;
      if h = 'do-not-log-address' then
        dontLogAddressMask := l;
      if h = 'out-total' then
        outTotalOfs := int;
      if h = 'in-total' then
        inTotalOfs := int;
      if h = 'hits-total' then
        hitsLogged := int;
      if h = 'downloads-total' then
        downloadsLogged := int;
      if h = 'upload-total' then
        uploadsLogged := int;
      if h = 'min-disk-space' then
        minDiskSpace := int;
      if h = 'flash-on' then
        flashOn := l;
      if h = 'last-external-address' then
        dyndns.lastIP := l;
      if h = 'recents' then
        recentFiles := split(';', l);
      // legacy: moved to recent-files because the split-char changed in #111
      if h = 'recent-files' then
        recentFiles := split('|', l);
      if h = 'trusted-files' then
        trustedFiles := split('|', l);
      if h = 'ips-ever-connected' then
        ipsEverConnected.DelimitedText := l;
      if h = 'mime-types' then
        mimeTypes := split('|', l);
      if h = 'in-browser-if-mime' then
        inBrowserIfMIME := yes;
      if h = 'address2name' then
        address2name := split('|', l);
      if h = 'compressed-browsing' then
        compressedbrowsingChk.checked := yes;
      if h = 'hints4newcomers' then
        HintsfornewcomersChk.checked := yes;
      if h = 'tester-updates' then
        testerUpdatesChk.checked := yes;
      if h = 'number-files-on-upload' then
        numberFilesOnUploadChk.checked := yes;
      if h = 'many-items-warning' then
        warnManyItems := yes;
      if h = 'load-single-comment-files' then
        loadSingleCommentsChk.checked := yes;
      if h = 'accounts' then
        strToAccounts();
      if h = 'use-iso-date-format' then
        useISOdateChk.checked := yes;
      if h = 'auto-comment' then
        autoCommentChk.checked := yes;
      if h = 'icon-masks-user-images' then
        readUserIconMasks();
      if h = 'icon-masks' then
        strToIconmasks();
      if h = 'connections-columns' then
        serializedConnColumns := l;
      if h = 'ip-services' then
        IPservices := split(';', l);
      if h = 'ip-services-time' then
        IPservicesTime := real;
      if h = 'update-automatically' then
        updateAutomaticallyChk.checked := yes;
      if h = 'delayed-update' then
        delayUpdateChk.checked := yes;
      if h = 'links-before' then
        linksBeforeChk.checked := yes;
      if h = 'account-notes-wrap' then
        optionsFrm.notesWrapChk.checked := yes;

      if h = 'graph-visible' then
        if yes then
          showGraph()
        else
          hideGraph();
      // extra commands for external use
      if h = 'load-tpl-from' then
        setNewTplFile(l);
    except
    end;
  end;

  if not alreadyStarted then
    // i was already seeing all the stuff, so please don't hide it
    if (build > '') and (build < '006') then
      easyMode := FALSE;

  if not alreadyStarted and not saveTotalsChk.checked then
  begin
    outTotalOfs := 0;
    inTotalOfs := 0;
    hitsLogged := 0;
    downloadsLogged := 0;
    uploadsLogged := 0;
  end;
  findSimilarIP(savedip);
  if lastGoodLogWidth > 0 then
    logbox.Width := lastGoodLogWidth;
  if lastGoodConnHeight > 0 then
    connPnl.height := lastGoodConnHeight;
  if not fileExists(tplFilename) then
    setTplText(defaultTpl);
  srv.persistentConnections := persistentconnectionsChk.checked;
  applyFilesBoxRatio();
  updateRecentFilesMenu();
  keepTplUpdated();
  updateAlwaysOnTop();
  applyISOdateFormat();
  // the filematch() would be fooled by spaces, so lets trim
  for i := 0 to length(mimeTypes) - 1 do
    mimeTypes[i] := trim(mimeTypes[i]);

  addMissingMimeTypes();
  for i := 0 to length(warnings) - 1 do
    msgDlg(warnings[i], MB_ICONWARNING);
  if alreadyStarted then
    if activateServer <> srv.active then
      toggleServer()
    else
  else if activateServer then
    startServer();
  result := TRUE;

  updateCurrentCFG();
end; // setcfg

function loadCfg(var ini, tpl: string): boolean;

// until 2.2 the template could be kept in the registry, so we need to move it now.
// returns true if the registry source can be deleted
  function moveLegacyTpl(tpl: string): boolean;
  begin
    result := FALSE;
    if (tplFilename > '') or (tpl = '') then
      exit;
    tplFilename := cfgPath + TPL_FILE;
    result := saveFile(tplFilename, tpl);
  end; // moveLegacyTpl

begin
  result := TRUE;
  ipsEverConnected.text := loadFile(IPS_FILE);
  ini := loadFile(cfgPath + CFG_FILE);
  if ini > '' then
  begin
    saveMode := SM_FILE;
    moveLegacyTpl(loadFile(cfgPath + TPL_FILE));
    exit;
  end;
  ini := loadregistry(CFG_KEY, '');
  if ini > '' then
  begin
    saveMode := SM_USER;
    if moveLegacyTpl(loadregistry(CFG_KEY, TPL_FILE)) then
      deleteRegistry(CFG_KEY, TPL_FILE);
    exit;
  end;
  ini := loadregistry(CFG_KEY, '', HKEY_LOCAL_MACHINE);
  if ini > '' then
  begin
    saveMode := SM_SYSTEM;
    if moveLegacyTpl(loadregistry(CFG_KEY, TPL_FILE, HKEY_LOCAL_MACHINE)) then
      deleteRegistry(CFG_KEY, TPL_FILE, HKEY_LOCAL_MACHINE);
    exit;
  end;
  result := FALSE;
end; // loadCfg

procedure Tmainfrm.Viewhttprequest1Click(Sender: Tobject);
var
  cd: TconnData;
begin
  cd := selectedConnection();
  if cd = NIL then
    exit;
  msgDlg(first([cd.conn.request.full, cd.conn.getBuffer(), '(empty)']));
end;

procedure Tmainfrm.connmenuPopup(Sender: Tobject);
var
  bs, // is there any connection selected?
  ba: boolean; // is there any connection listed and connected?
  i: integer;
  cd: TconnData;
begin
  cd := selectedConnection();
  bs := assigned(cd);
  ba := FALSE;
  for i := 0 to connBox.items.count - 1 do
    if conn2data(i).conn.state <> HCS_DISCONNECTED then
    begin
      ba := TRUE;
      break;
    end;
  Viewhttprequest1.enabled := bs;
  BanIPaddress1.enabled := bs;
  Kickconnection1.enabled := bs and (cd.conn.state <> HCS_DISCONNECTED);
  KickIPaddress1.enabled := bs and ba;
  Kickallconnections1.enabled := ba;
  Kickidleconnections1.enabled := ba;
  pause1.visible := bs and isDownloading(cd);
  pause1.checked := bs and cd.conn.paused;

  trayiconforeachdownload1.visible := trayfordownloadChk.checked and fromTray;
end;

function expandAccountByLink(a: Paccount; noGroups: boolean = TRUE)
  : TStringDynArray;
var
  i: integer;
begin
  result := NIL;
  if a = NIL then
    exit;

  if not(a.group and noGroups) then
    addString(a.user, result);
  for i := 0 to length(accounts) - 1 do
    if not stringExists(accounts[i].user, result) and
      stringExists(a.user, accounts[i].link) then
      addArray(result, expandAccountByLink(@accounts[i]));
  uniqueStrings(result);
end; // expandAccountByLink

function expandAccountsByLink(users: TStringDynArray; noGroups: boolean = TRUE)
  : TStringDynArray;
var
  i: integer;
begin
  result := NIL;
  for i := 0 to length(users) - 1 do
    addArray(result, expandAccountByLink(getAccount(users[i], TRUE)));
  uniqueStrings(result);
end; // expandAccountsByLink

procedure makeOwnerDrawnMenu(mi: TMenuItem; included: boolean = FALSE);
var
  i: integer;
begin
  if included then
  begin
    mi.onDrawItem := mainfrm.menuDraw;
    mi.OnMeasureItem := mainfrm.menuMeasure;
  end;
  for i := 0 to mi.count - 1 do
    makeOwnerDrawnMenu(mi.items[i], TRUE);
end; // makeOwnerDrawnMenu

procedure Tmainfrm.filemenuPopup(Sender: Tobject);
const
  ONLY_ANY = 0;
  ONLY_EASY = 1;
  ONLY_EXPERT = 2;
var
  anyFileSelected: boolean;
  i: integer;
  f: Tfile;
  a: TStringDynArray;

  function onlySatisfied(only: integer): boolean;
  begin
    result := (only = ONLY_ANY) or (only = ONLY_EASY) and easyMode or
      (only = ONLY_EXPERT) and not easyMode
  end; // onlySatisfied

  procedure visibleAs(mi: TMenuItem; other: TMenuItem;
    only: integer = ONLY_ANY);
  begin
    mi.visible := other.visible and onlySatisfied(only)
  end;

  procedure visibleIf(mi: TMenuItem; should: boolean; only: integer = ONLY_ANY);
  begin
    if should then
      mi.visible := TRUE and onlySatisfied(only)
  end;

  procedure checkedIf(mi: TMenuItem; should: boolean);
  begin
    if should then
      mi.checked := TRUE
  end;

  procedure enabledIf(mi: TMenuItem; should: boolean);
  begin
    if should then
      mi.enabled := TRUE
  end;

  procedure setDefaultValues(mi: TMenuItem);
  var
    i: integer;
  begin
    for i := 0 to mi.count - 1 do
    begin
      mi[i].visible := FALSE;
      mi[i].enabled := TRUE;
      mi[i].checked := FALSE;
    end;
  end; // setDefaultValues

  function itemsVisible(mi: TMenuItem): integer;
  var
    i: integer;
  begin
    result := 0;
    for i := 0 to mi.count - 1 do
      if mi.items[i].visible then
        inc(result);
  end; // itemsVisible

begin
  // default values
  setDefaultValues(filemenu.items);
  Addfiles1.visible := TRUE;
  Addfolder1.visible := TRUE;
  Properties1.visible := TRUE;

  anyFileSelected := selectedFile <> NIL;
  newfolder1.visible := not anyFileSelected or
    ((filesbox.SelectionCount = 1) and selectedFile.isFolder());
  Setuserpass1.visible := anyFileSelected;
  CopyURL1.visible := anyFileSelected;

  visibleIf(Bindroottorealfolder1, (filesbox.SelectionCount = 1) and
    selectedFile.isRoot() and selectedFile.isVirtualFolder(), ONLY_EXPERT);
  visibleIf(Unbindroot1, (filesbox.SelectionCount = 1) and selectedFile.isRoot()
    and selectedFile.isRealFolder(), ONLY_EXPERT);

  for i := 0 to filesbox.SelectionCount - 1 do
  begin
    f := filesbox.selections[i].data;
    visibleIf(setURL1, FA_LINK in f.flags);
    visibleIf(remove1, not f.isRoot());
    visibleIf(Flagasnew1, not f.isNew() and (filesStayFlaggedForMinutes > 0));
    visibleIf(Resetnewflag1, f.isNew() and (filesStayFlaggedForMinutes > 0));
    visibleIf(SwitchToVirtual1, f.isRealFolder() and not f.isRoot(),
      ONLY_EXPERT);
    visibleIf(SwitchToRealfolder1, f.isVirtualFolder() and not f.isRoot() and
      (f.resource > ''), ONLY_EXPERT);
    visibleIf(Resetuserpass1, f.user > '');
    visibleIf(CopyURLwithfingerprint1, f.isFile(), ONLY_EXPERT);
  end;
  visibleAs(newlink1, newfolder1, ONLY_EXPERT);
  visibleIf(purge1, anyFileSelected, ONLY_EXPERT);

  if filesbox.SelectionCount = 1 then
  begin
    f := selectedFile;
    visibleIf(Defaultpointtoaddfiles1, f.isFolder(), ONLY_EXPERT);
    visibleIf(Editresource1, not(FA_VIRTUAL in f.flags), ONLY_EXPERT);
    visibleAs(rename1, remove1);
    visibleIf(openit1, not f.isVirtualFolder());
    visibleIf(browseIt1, TRUE, ONLY_EXPERT);
    Paste1.visible := clipboard.HasFormat(CF_HDROP);

    a := NIL;
    if anyFileSelected then
      a := expandAccountsByLink(selectedFile.getAccountsFor(FA_ACCESS, TRUE));
    visibleIf(CopyURLwithpassword1, assigned(a), ONLY_EXPERT);
    CopyURLwithpassword1.clear();
    for i := 0 to length(a) - 1 do
      CopyURLwithpassword1.add(newItem(a[i], 0, FALSE, TRUE,
        copyURLwithPasswordMenuClick, 0, ''));
  end;

  a := getPossibleAddresses();
  if length(a) = 1 then
    a := NIL;
  visibleIf(CopyURLwithdifferentaddress1, anyFileSelected and assigned(a),
    ONLY_EXPERT);
  CopyURLwithdifferentaddress1.clear();
  for i := 0 to length(a) - 1 do
    CopyURLwithdifferentaddress1.add(newItem(a[i], 0, FALSE, TRUE,
      copyURLwithAddressMenuclick, 0, ''));

end;

function Tmainfrm.saveCFG(): boolean;

  procedure proposeUserRegistry();
  const
    msg = 'Can''t save options there.' +
      #13'Should I try to save to user registry?';
  begin
    if msgDlg(msg, MB_ICONERROR + MB_YESNO) = IDYES then
    begin
      saveMode := SM_USER;
      saveCFG();
    end;
  end; // proposeUserRegistry

var
  cfg: string;
begin
  result := FALSE;
  if srv = NIL then
    exit;
  if quitting and (backuppedCfg > '') then
    cfg := backuppedCfg
  else
    cfg := getCfg();
  case saveMode of
    SM_FILE:
      begin
        if not saveFile(cfgPath + CFG_FILE, cfg) then
        begin
          proposeUserRegistry();
          exit;
        end;
        result := TRUE;
      end;
    SM_SYSTEM:
      begin
        deleteFile(cfgPath + CFG_FILE);
        deleteRegistry(CFG_KEY);
        if not saveregistry(CFG_KEY, '', cfg, HKEY_LOCAL_MACHINE) then
        begin
          proposeUserRegistry();
          exit;
        end;
        result := TRUE;
      end;
    SM_USER:
      begin
        deleteFile(cfgPath + CFG_FILE);
        result := saveregistry(CFG_KEY, '', cfg);
      end;
  end;
  if ipsEverConnected.count >= IPS_THRESHOLD then
    saveFile(IPS_FILE, ipsEverConnected.text)
  else
    deleteFile(IPS_FILE);

  if result then
    deleteFile(lastUpdateCheckFN);
end; // saveCFG

// this method is called by all "save options" ways
procedure Tmainfrm.tofile1Click(Sender: Tobject);
begin
  if Sender = tofile1 then
    saveMode := SM_FILE
  else if Sender = toregistrycurrentuser1 then
    saveMode := SM_USER
  else if Sender = toregistryallusers1 then
    saveMode := SM_SYSTEM
  else
    exit;

  if saveCFG() then
    msgDlg(MSG_OPTIONS_SAVED);
end;

procedure Tmainfrm.About1Click(Sender: Tobject);
begin
  msgDlg(format(getRes('copyright'), [HFS.Consts.VERSION, VERSION_BUILD]))
end;

procedure Tmainfrm.purgeConnections();
var
  i: integer;
  data: TconnData;
begin
  i := 0;
  while i < toDelete.count do
  begin
    data := toDelete[i];
    inc(i);
    if data = NIL then
      continue;
    if assigned(data.conn) and data.conn.dontFree then
      continue;
    toDelete[i - 1] := NIL;
    setupDownloadIcon(data);
    data.lastFile := NIL; // auto-freeing

    if assigned(data.limiter) then
    begin
      srv.limiters.REMOVE(data.limiter);
      freeAndNIL(data.limiter);
    end;
    freeAndNIL(data.conn);
    try
      freeAndNIL(data)
    except
    end;
  end;
  toDelete.clear();
end; // purgeConnections

procedure Tmainfrm.recalculateGraph();
var
  i: integer;
begin
  if (srv = NIL) or quitting then
    exit;
  // shift samples
  i := SizeOf(graph.samplesOut) - SizeOf(graph.samplesOut[0]);
  move(graph.samplesOut[0], graph.samplesOut[1], i);
  move(graph.samplesIn[0], graph.samplesIn[1], i);
  // insert new "out" sample
  graph.samplesOut[0] := srv.bytesSent - graph.lastOut;
  graph.lastOut := srv.bytesSent;
  // insert new "in" sample
  graph.samplesIn[0] := srv.bytesReceived - graph.lastIn;
  graph.lastIn := srv.bytesReceived;
  // increase the max value
  i := max(graph.samplesOut[0], graph.samplesIn[0]);
  if i > graph.maxV then
  begin
    graph.maxV := i;
    graph.beforeRecalcMax := 100;
  end;
  dec(graph.beforeRecalcMax);
  if graph.beforeRecalcMax > 0 then
    exit;
  // recalculate max value
  graph.maxV := 0;
  with graph do
    for i := 0 to length(samplesOut) - 1 do
      maxV := max(maxV, max(samplesOut[i], samplesIn[i]));
  graph.beforeRecalcMax := 100;
end; // recalculateGraph

// parse the version-dependant notice
procedure parseVersionNotice(s: string);
var
  l, msg: string;
begin
  while s > '' do
  begin
    l := trim(chopLine(s));
    // the line has to start with a @ followed by involved versions
    if (length(l) < 2) or (l[1] <> '@') then
      continue;
    Delete(l, 1, 1);
    // collect the message (until next @-starting line)
    msg := '';
    while (s > '') and (s[1] <> '@') do
      msg := msg + chopLine(s) + #13;
    // before 2.0 beta14 a bare semicolon-separated string comparison was used
    if fileMatch(l, HFS.Consts.VERSION) or fileMatch(l, '#' + VERSION_BUILD) then
      msgDlg(msg, MB_ICONWARNING);
  end;
end; // parseVersionNotice

function doTheUpdate(url: string): boolean;
const
  MSG_SAVE_ERROR = 'Cannot save the update';
  MSG_LIMITED =
    'The auto-update feature cannot work because it requires the "Only 1 instance" option enabled.'
    + #13#13'Your browser will now be pointed to the update, so you can install it manually.';
  UPDATE_BATCH_FILE = 'hfs.update.bat';
  UPDATE_BATCH = 'START %0:s /WAIT "%1:s" -q' + CRLF +
    'ping 127.0.0.1 -n 3 -w 1000> nul' + CRLF + 'DEL "%3:s' + PREVIOUS_VERSION +
    '"' + CRLF + '%2:sMOVE "%1:s" "%3:s' + PREVIOUS_VERSION + '"' + CRLF +
    'DEL "%1:s"' + CRLF + 'MOVE "%4:s" "%1:s"' + CRLF + 'START %0:s "%1:s"' +
    CRLF + 'DEL %%0' + CRLF;
var
  size: integer;
  fn: string;
begin
  result := FALSE;
  if not mono.working then
  begin
    msgDlg(MSG_LIMITED, MB_ICONWARNING);
    openURL(url);
    exit;
  end;
  if mainfrm.delayUpdateChk.checked and (srv.conns.count > 0) then
  begin
    updateASAP := url;
    stopServer();
    mainfrm.kickidleconnections1Click(NIL);
    mainfrm.setStatusBarText
      ('Waiting for last requests to be served, then we''ll update', 20);
    exit;
  end;
  // must ask BEFORE: when the batch will be running, nothing should stop it, or it will fail
  if not checkVfsOnQuit() then
    exit;
  VFSmodified := FALSE;

  progFrm.show('Downloading new version...', TRUE);
  try
    fn := paramStr(0) + '.new';
    size := sizeOfFile(fn);
    // a previous failed update attempt? avoid re-downloading if not necessary
    if (size <= 0) or (httpFileSize(url) <> size) then
      try
        if not httpGetFile(url, fn, 2, mainfrm.progFrmHttpGetUpdate) then
        begin
          if not lockTimerevent then
            msgDlg(MSG_COMM_ERROR, MB_ICONERROR);
          exit;
        end;
      except
        if not lockTimerevent then
          msgDlg(MSG_SAVE_ERROR, MB_ICONERROR);
        exit;
      end;
  finally
    progFrm.hide()
  end;
  if progFrm.cancelRequested then
  begin
    deleteFile(fn);
    exit;
  end;

  try
    progFrm.show('Processing...');
    saveFile(UPDATE_BATCH_FILE, format(UPDATE_BATCH, [if_(isNT(), '""'),
      paramStr(0), if_(not mainfrm.keepBakUpdatingChk.checked, 'REM '),
      exePath, fn]));
    execNew(UPDATE_BATCH_FILE);
    result := TRUE;
  finally
    progFrm.hide()
  end;
end; // doTheUpdate

function promptForUpdating(url: string): boolean;
const
  MSG_UPDATE = 'You are invited to use the new version.'#13#13'Update now?';
begin
  result := FALSE;
  if url = '' then
    exit;
  if not mainfrm.updateAutomaticallyChk.checked and
    (msgDlg(MSG_UPDATE, MB_YESNO) = IDNO) then
    exit;
  doTheUpdate(url);
  result := TRUE;
end; // promptForUpdating

function downloadUpdateInfo(): TTemplate;
const
  url = 'http://www.rejetto.com/hfs/hfs.updateinfo.txt';
  ON_DISK = 'hfs.updateinfo.txt';
  MSG_FROMDISK = 'Update info has been read from local file.' +
    #13'To resume normal operation of the updater, delete the file ' + ON_DISK +
    ' from the HFS program folder.';
var
  s: string;
begin
  lastUpdateCheck := now();
  saveFile(lastUpdateCheckFN, '');
  fileSetAttr(lastUpdateCheckFN, faHidden);

  result := NIL;
  progFrm.show('Requesting...');
  try
    // this let the developer to test the parsing locally
    if not fileExists(ON_DISK) then
      try
        s := httpGet(url)
      except
      end
    else
    begin
      s := loadFile(ON_DISK);
      msgDlg(MSG_FROMDISK, MB_ICONWARNING);
    end;
  finally
    progFrm.hide()
  end;
  if pos('[EOF]', s) = 0 then
    exit;
  result := TTemplate.create();
  result.fullText := s;
end; // downloadUpdateInfo

procedure Tmainfrm.autoCheckUpdates();
var
  info: TTemplate;
  updateURL, ver, build: string;

  function thereSnew(kind: string): boolean;
  var
    s: string;
  begin
    s := trim(info['last ' + kind + ' build']);
    result := (s > VERSION_BUILD) and (s <> refusedUpdate);
    if not result then
      exit;
    build := s;
    updateURL := trim(info['last ' + kind + ' url']);
    ver := trim(info['last ' + kind]);
  end;

begin
  if (VERSION_STABLE and (now() - lastUpdateCheck < 1)) or
    (now() - lastUpdateCheck < 1 / 3) then
    exit;
  setStatusBarText('Checking for updates');
  try
    info := downloadUpdateInfo();
    if info = NIL then
    begin
      if logOtherEventsChk.checked then
        add2log('Check update: failed');
      setStatusBarText('Check update: failed');
      exit;
    end;
    if not thereSnew('stable') and
      (not VERSION_STABLE or testerUpdatesChk.checked) then
      thereSnew('untested');
    // same version? we show build number
    if ver = HFS.Consts.VERSION then
      ver := format('Build #%s (current is #%s)', [build, VERSION_BUILD]);
    if logOtherEventsChk.checked then
      add2log('Check update: ' + ifThen(updateURL = '', 'no new version',
        'new version found: ' + ver));
    parseVersionNotice(info['version notice']);
    setStatusBarText('');
    if updateURL = '' then
      exit;
    if updateAutomaticallyChk.checked and doTheUpdate(updateURL) then
      exit;
    // notify the user gently
    updateBtn.show();
    updateWaiting := updateURL;
    flash();
  finally
    freeAndNIL(info)
  end;
end; // autoCheckUpdates

procedure loadEvents();
begin
  eventScripts.fullText := loadFile(cfgPath + EVENTSCRIPTS_FILE)
end;

procedure Tmainfrm.updateCopyBtn();
var
  s: string;
begin
  s := copyBtn.Caption;
  try
    copyBtn.Caption := if_(clipboard.AsText = urlBox.text,
      'Already in clipboard', 'Copy to clipboard');
    if copyBtn.Caption <> s then
      FormResize(NIL);
  except
  end;
end; // updateCopyBtn

var
  timedEventsRE: TregExpr;
  eventsLastRun: TstringToIntHash;

procedure runTimedEvents();
var
  i: integer;
  sections: TStringDynArray;
  re: TregExpr;
  t, last: Tdatetime;
  section: string;

  procedure handleAtCase();
  begin
    t := now();
    // we must convert the format, because our structure stores integers
    last := unixToDatetime(eventsLastRun.getInt(section));
    if (strToInt(re.match[9]) = hourOf(t)) and
      (strToInt(re.match[10]) = minuteOf(t)) and (t - last > 0.9) then
    // approximately 1 day should have been passed
    begin
      eventsLastRun.setInt(section, datetimeToUnix(t));
      runEventScript(section);
    end;
  end; // handleAtCase

  procedure handleEveryCase();
  begin
    // get the XX:YY:ZZ
    t := strToFloat(re.match[2]);
    if re.match[4] > '' then
      t := t * 60 + strToInt(re.match[4]);
    if re.match[6] > '' then
      t := t * 60 + strToInt(re.match[6]);
    // apply optional time unit
    case upcase(getFirstChar(re.match[7])) of
      'M':
        t := t * 60;
      'H':
        t := t * 60 * 60;
    end;
    // now "t" is in seconds
    if (t > 0) and ((clock div 10) mod round(t) = 0) then
      runEventScript(section);
  end; // handleEveryCase

begin
  if timedEventsRE = NIL then
  begin
    timedEventsRE := TregExpr.create;
    // yes, i know, this is never freed, but we need it for the whole time
    timedEventsRE.expression :=
      '(every +([0-9.]+)(:(\d+)(:(\d+))?)? *([a-z]*))|(at (\d+):(\d+))';
    timedEventsRE.modifierI := TRUE;
    timedEventsRE.compile();
  end;

  if eventsLastRun = NIL then
    eventsLastRun := TstringToIntHash.create;
  // yes, i know, this is never freed, but we need it for the whole time

  re := timedEventsRE; // a shortcut
  sections := eventScripts.getSections();
  for i := 0 to length(sections) - 1 do
  begin
    section := sections[i]; // a shortcut
    if not re.exec(section) then
      continue;

    try
      if re.match[1] > '' then
        handleEveryCase()
      else
        handleAtCase();
    except
    end; // ignore exceptions
  end;
end; // runTimedEvents

procedure Tmainfrm.timerEvent(Sender: Tobject);
var
  now_: Tdatetime;

  function itsTimeFor(var t: Tdatetime): boolean;
  begin
    result := (t > 0) and (t < now_);
    if result then
      t := 0;
  end; // itsTimeFor

  procedure calculateETA(data: TconnData; current: real; leftOver: int64);
  var
    i, n: integer;
  begin
    data.eta.data[data.eta.idx mod ETA_FRAME] := current;
    inc(data.eta.idx);

    data.averageSpeed := 0;
    n := min(data.eta.idx, ETA_FRAME);
    for i := 0 to n - 1 do
      data.averageSpeed := data.averageSpeed + data.eta.data[i];
    data.averageSpeed := data.averageSpeed / n;

    if data.averageSpeed > 0 then
      data.eta.result := (leftOver / data.averageSpeed) / SECONDS;
  end; // calculateETA

  procedure every10minutes();
  begin
    if dyndns.url > '' then
      getExternalAddress(externalIP);
  end; // every10minutes

  procedure everyMinute();
  begin
    if updateDailyChk.checked then
      autoCheckUpdates();
    // purge icons older than 5 minutes, because sometimes icons change
    iconsCache.purge(now_ - (5 * 60) / SECONDS);
  end; // everyMinute

  procedure every10sec();
  var
    s: string;
    ss: Tstrings;
  begin
    if not stringExists(defaultIP, getPossibleAddresses()) then
      // previous address not available anymore (it happens using dial-up)
      findSimilarIP(defaultIP);

    if searchbetteripChk.checked and not stringExists(defaultIP, customIPs)
    // we don't mess with custom IPs
      and isLocalIP(defaultIP) then // we prefer non-local addresses
    begin
      s := getIP();
      if not isLocalIP(s) then // clearly better
        setDefaultIP(s)
      else if ansiStartsStr('169', defaultIP) then
      // we consider the 169 worst of other locals
      begin
        ss := localIPlist();
        if ss.count > 1 then
          setDefaultIP(ss[if_(ss[0] = defaultIP, 1, 0)]);
      end;;
    end;

  end; // every10sec

  procedure everySec();
  var
    i, outside, size: integer;
    data: TconnData;
  begin
    // this is a already done in utilLib initialization, but it's a workaround to http://www.rejetto.com/forum/?topic=7724
    FormatSettings.decimalSeparator := '.';
    // check if the window is outside the visible screen area
    outside := left;
    if assigned(monitor) then
    // checking here because the following line once thrown this AV http://www.rejetto.com/forum/?topic=5568
      for i := 0 to monitor.MonitorNum do
        dec(outside, screen.monitors[i].Width);
    if outside > 0 then
      makeFullyVisible();

    if dyndns.active and (dyndns.url > '') then
    begin
      if externalIP = '' then
        getExternalAddress(externalIP);
      if not isLocalIP(externalIP) and (externalIP <> dyndns.lastIP) or
        (now() - dyndns.lastTime > 24) then
        updateDynDNS();
      // the action above takes some time, and it can happen we asked to quit in the meantime
      if quitting then
        exit;
    end;

    // the alt+click shortcut to get file properties will result in an unwanted editing request if the file is already selected. This is a workaround.
    if filesbox.IsEditing and assigned(filepropFrm) then
      selectedFile.node.EndEdit(TRUE);

    updateTrayTip();

    if warnManyItems and (filesbox.items.count > MANY_ITEMS_THRESHOLD) then
    begin
      warnManyItems := FALSE;
      msgDlg(MSG_MANY_ITEMS, MB_ICONWARNING);
    end;

    with autosaveVFS do // we do it only if the filename is already specified
      if (every > 0) and (lastFileOpen > '') and
        not loadingVFS.disableAutosave and ((now_ - last) * SECONDS >= every)
      then
      begin
        last := now_;
        saveVFS(lastFileOpen);
      end;

    if assigned(srv) and assigned(srv.conns) then
      for i := 0 to srv.conns.count - 1 do
      begin
        data := conn2data(i);
        if data = NIL then
          continue;

        if isReceivingFile(data) then
        begin
          refreshConn(data);
          // even if no data is coming, we must update other stats
          calculateETA(data, data.conn.speedIn, data.conn.bytesToPost);
        end;
        if isSendingFile(data) then
        begin
          refreshConn(data);
          calculateETA(data, data.conn.speedOut, data.conn.bytesToSend);

          if userIcsBuffer > 0 then
            data.conn.sock.bufSize := userIcsBuffer;

          size := minmax(8192, MEGA, round(data.averageSpeed));
          if userSocketBuffer > 0 then
            data.conn.sndBuf := userSocketBuffer
          else if highSpeedChk.checked and
            (safeDiv(0.0 + size, data.conn.sndBuf, 2) > 2) then
            data.conn.sndBuf := size;
        end;

        // connection inactivity timeout
        if (connectionsInactivityTimeout > 0) and
          ((now_ - data.lastActivityTime) * SECONDS >=
          connectionsInactivityTimeout) then
          data.disconnect('inactivity');
      end;

    // server inactivity timeout
    if noDownloadTimeout > 0 then
      if (now_ - lastActivityTime) * SECONDS > noDownloadTimeout * 60 then
        quitASAP := TRUE;

    if windowState = wsNormal then
      lastWindowRect := mainfrm.boundsRect;

    // update can be put off until there's no one connected
    if (updateASAP > '') and (srv.conns.count = 0) then
      doTheUpdate(clearAndReturn(updateASAP));
    // before we call the function, lets clear the request

    updateCopyBtn();
    keepTplUpdated();
    updateCurrentCFG();

    if newMtime(cfgPath + EVENTSCRIPTS_FILE, eventScriptsLast) then
      loadEvents();

    if assigned(runScriptFrm) and runScriptFrm.visible and
      runScriptFrm.autorunChk.checked and newMtime(tempScriptFilename,
      runScriptLast) then
      runScriptFrm.runBtnClick(NIL);

    runTimedEvents();
  end; // everySec

  procedure everyTenth();
  var
    f: Tfile;
    n: TtreeNode;
  begin
    purgeConnections();

    // see the filesBoxEditing event for an explanation of the following lines
    if not filesbox.IsEditing and (remove1.ShortCut = 0) then
    begin
      remove1.ShortCut := TextToShortCut('Del');
      Paste1.ShortCut := TextToShortCut('Ctrl+V');
    end;

    with optionsFrm do
      if active and iconsPage.visible then
        updateIconMap();

    if scrollFilesBox in [SB_LINEUP, SB_LINEDOWN] then
      postMessage(filesbox.Handle, WM_VSCROLL, scrollFilesBox, 0);

    if assigned(filesToAddQ) then
    begin
      f := findFilebyURL(addToFolder);
      if f = NIL then
        f := selectedFile;
      if f = NIL then
        n := NIL
      else
        n := f.node;
      addFilesFromString(join(CRLF, filesToAddQ), n);
      filesToAddQ := NIL;
    end;

    if itsTimeFor(searchLogTime) then
      if searchLog(0) then
        logSearchBox.color := clWindow
      else
      begin
        logSearchBox.color := BG_ERROR;
        searchLogWhiteTime := now_ + 5 / SECONDS;
      end;
    if itsTimeFor(searchLogWhiteTime) then
      logSearchBox.color := clWindow;

  end; // everyTenth

  function every(tenths: integer): boolean;
  begin
    result := not quitting and (clock mod tenths = 0)
  end;

var
  bak: boolean;
begin
  if quitASAP and not quitting and not queryingClose then
  begin
    { close is not effective when lockTimerevent is TRUE, so we force it TRUE.
      { it should not be necessary, but we want to be sure to quit even with bugs. }
    bak := lockTimerevent;
    lockTimerevent := FALSE;
    application.MainForm.Close();
    lockTimerevent := bak;
  end; // quit
  if not timer.enabled or quitting or lockTimerevent then
    exit;
  lockTimerevent := TRUE;
  try
    // idk how it can be, but sometimes this now() call causes an AV http://www.rejetto.com/forum/index.php?topic=6371.msg1038634#msg1038634
    try
      now_ := now()
    except
      now_ := 0
    end;
    if now_ = 0 then
      exit;

    inc(clock);
    if every(1) then
      everyTenth();
    if every(10 * 60 * 10) then
      every10minutes();
    if every(60 * 10) then
      everyMinute();
    if every(10 * 10) then
      every10sec();
    if every(10) then
      everySec();
    if every(STATUSBAR_REFRESH) then
      updateSbar();
    if every(graph.rate) then
    begin
      recalculateGraph();
      graphBoxPaint(NIL);
    end;
  finally
    lockTimerevent := FALSE
  end;
end; // timerEvent

procedure Tmainfrm.updateSbar();
var
  pn: integer;

  function addPanel(s: string; al: TAlignment = taCenter): integer;
  begin
    result := pn;
    inc(pn);
    if sbar.Panels.count < pn then
      sbar.Panels.add();
    with sbar.Panels[pn - 1] do
    begin
      alignment := al;
      text := s;
      Width := sbar.Canvas.TextWidth(s) + 20;
    end;
  end; // addPanel

  procedure checkDiskSpace();
  type
    Tdrive = 1 .. 26;
  var
    i: integer;
    drives: set of Tdrive;
    driveLetters: TStringDynArray;
    driveLetter: char;
  begin
    if minDiskSpace <= 0 then
      exit;
    drives := [];
    i := 0;
    while i < length(uploadPaths) do
    begin
      include(drives, filenameToDriveByte(uploadPaths[i]));
      inc(i);
    end;
    driveLetters := NIL;
    for i := low(Tdrive) to high(Tdrive) do
      if i in drives then
      begin
        driveLetter := chr(i + ord('A') - 1);
        if not System.SysUtils.DirectoryExists(driveLetter + ':\') then
          continue;
        if diskfree(i) div MEGA <= minDiskSpace then
          addString(driveLetter, driveLetters);
      end;
    if driveLetters = NIL then
      exit;
    sbarIdxs.oos := addPanel('Out of space: ' + join(',', driveLetters));
  end; // checkDiskSpace

  function getConnectionsString(): string;
  var
    i: integer;
  begin
    result := format('Connections: %d', [srv.conns.count]);
    if easyMode then
      exit;
    i := countIPs();
    if i < srv.conns.count then
      result := result + ' / ' + intToStr(i);
  end;

var
  tempText: string;
begin
  if quitting then
    exit;
  fillChar(sbarIdxs, SizeOf(sbarIdxs), -1);
  if sbarTextTimeout < now() then
    tempText := ''
  else
    tempText := sbar.Panels[sbar.Panels.count - 1].text;
  pn := 0;
  if not easyMode then
    addPanel(getConnectionsString());
  sbarIdxs.out := addPanel(format('Out: %.1f KB/s', [srv.speedOut / 1000]));
  addPanel(format('In: %.1f KB/s', [srv.speedIn / 1000]));
  if not easyMode then
  begin
    sbarIdxs.totalOut :=
      addPanel(format('Total Out: %s',
      [smartsize(outTotalOfs + srv.bytesSent)]));
    sbarIdxs.totalIn :=
      addPanel(format('Total In: %s',
      [smartsize(inTotalOfs + srv.bytesReceived)]));
    sbarIdxs.notSaved :=
      addPanel(format('VFS: %d items', [filesbox.items.count - 1]) +
      if_(VFSmodified, ' - not saved'));
    if not VFSmodified then
      sbarIdxs.notSaved := -1;
  end;
  checkDiskSpace();

  if showMemUsageChk.checked then
    addPanel('Mem: ' + dotted(allocatedMemory()));

  if assigned(banlist) then
    sbarIdxs.banStatus := addPanel(format('Ban rules: %d', [length(banlist)]));

  if tplIsCustomized then
    sbarIdxs.customTpl := addPanel('Customized template');

  // if tempText empty, ensures a final panel terminator
  addPanel(tempText, taLeftJustify);

  // delete excess panels
  while sbar.Panels.count > pn do
    sbar.Panels.Delete(pn);
end; // updateSbar

procedure Tmainfrm.refreshIPlist();
CONST
  INDEX_FOR_URL = 2;
  INDEX_FOR_NIC = 1;
var
  a: TStringDynArray;
  i: integer;
begin
  while IPaddress1.items[INDEX_FOR_URL].Caption <> '-' do
    IPaddress1.Delete(INDEX_FOR_URL);
  // fill 'IP address' menu
  a := getPossibleAddresses();
  for i := 0 to length(a) - 1 do
    mainfrm.IPaddress1.Insert(INDEX_FOR_URL, newItem(a[i], 0, a[i] = defaultIP,
      TRUE, ipmenuclick, 0, ''));

  // fill 'Accept connections on' menu
  while Acceptconnectionson1.count > INDEX_FOR_NIC do
    Acceptconnectionson1.Delete(INDEX_FOR_NIC);
  Anyaddress1.checked := listenOn = '';
  a := listToArray(localIPlist);
  addUniqueString('127.0.0.1', a);
  for i := 0 to length(a) - 1 do
    Acceptconnectionson1.Insert(INDEX_FOR_NIC, newItem(a[i], 0, a[i] = listenOn,
      TRUE, acceptOnMenuclick, 0, ''));
end; // refreshIPlist

procedure Tmainfrm.filesBoxDblClick(Sender: Tobject);
begin
  if assigned(selectedFile) then
    setClip(selectedFile.fullURL());
  updateUrlBox();
end;

function setBrowsable(f: Tfile; childrenDone: boolean; par, par2: integer)
  : TfileCallbackReturn;
begin
  if not f.isFolder() then
    exit;
  if (FA_BROWSABLE in f.flags) = boolean(par) then
    VFSmodified := TRUE
  else
    exit;
  if boolean(par) then
    exclude(f.flags, FA_BROWSABLE)
  else
    include(f.flags, FA_BROWSABLE);
end; // setBrowsable

procedure fileMenuSetFlag(Sender: Tobject; flagToSet: TfileAttribute;
  filter: TfilterMethod = NIL; negateFilter: boolean = FALSE;
  recursive: boolean = FALSE; f: Tfile = NIL);
// parameter "f" is designed to be set only inside this function
var
  newState: boolean;

  procedure applyTo(f: Tfile);
  var
    n: TtreeNode;
  begin
    n := f.node.getFirstChild();
    while assigned(n) do
    begin
      if assigned(n.data) then
        fileMenuSetFlag(Sender, flagToSet, filter, negateFilter, TRUE, n.data);
      n := n.getNextSibling();
    end;

    if assigned(filter) and (negateFilter = filter(f)) then
      exit;
    if (flagToSet in f.flags) = newState then
      exit;
    VFSmodified := TRUE;
    if newState then
      include(f.flags, flagToSet)
    else
      exclude(f.flags, flagToSet);
  end; // applyTo

var
  i: integer;
begin
  if (f = NIL) and (selectedFile = NIL) then
    exit;
  newState := not(Sender as TMenuItem).checked;
  if assigned(f) then
    applyTo(f)
  else
  begin
    for i := 0 to mainfrm.filesbox.SelectionCount - 1 do
      applyTo(mainfrm.filesbox.selections[i].data);
    mainfrm.filesbox.Repaint();
  end;
end;

procedure Tmainfrm.HideClick(Sender: Tobject);
begin
  graphBox.hide();
  graphSplitter.hide();
end;

procedure Tmainfrm.filesBoxMouseDown(Sender: Tobject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
begin
  filesbox.Selected := filesbox.getNodeAt(x, y)
end;

procedure setFilesBoxExtras(v: boolean);
begin
  { let disable this silly feature for now
    if winVersion <> WV_VISTA then exit;
    with mainfrm.filesBox do
    begin
    if isEditing then exit;
    ShowButtons:=v;
    ShowLines:=v;
    end; }
end; // setFilesBoxExtras

procedure Tmainfrm.filesBoxMouseEnter(Sender: Tobject);
begin
  with filesbox do
    setFilesBoxExtras(TRUE);
end;

procedure Tmainfrm.filesBoxMouseLeave(Sender: Tobject);
begin
  with filesbox do
    setFilesBoxExtras(focused);
end;

procedure Tmainfrm.filesBoxMouseUp(Sender: Tobject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
begin
  if (Shift = [ssAlt]) and (Button = mbLeft) then
    Properties1.click();
end;

procedure Tmainfrm.filesBoxCompare(Sender: Tobject; Node1, Node2: TtreeNode;
  data: integer; var Compare: integer);
var
  f1, f2: Tfile;
begin
  f1 := Tfile(Node1.data);
  f2 := Tfile(Node2.data);
  if (f1 = NIL) or (f2 = NIL) then
    exit;
  if not foldersbeforeChk.checked or (f1.isFolder() = f2.isFolder()) then
    Compare := ansiCompareText(f1.name, f2.name)
  else if f1.isFolder() then
    Compare := -1
  else
    Compare := +1;
end;

procedure Tmainfrm.foldersbeforeChkClick(Sender: Tobject);
begin
  rootNode.AlphaSort(TRUE)
end;

procedure browse(url: string);
begin
  if mainfrm.browseUsingLocalhostChk.checked then
  begin
    chop('//', url);
    chop('/', url);
    url := 'http://localhost:' + srv.port + '/' + url;
  end;
  openURL(url);
end; // browse

procedure Tmainfrm.Browseit1Click(Sender: Tobject);
begin
  if selectedFile = NIL then
    exit;
  if selectedFile.isLink() then
    openURL(selectedFile.url())
  else
    browse(selectedFile.fullURL())
end;

procedure Tmainfrm.Openit1Click(Sender: Tobject);
begin
  if selectedFile = NIL then
    exit;
  exec('"' + selectedFile.resource + '"')
end;

procedure Tmainfrm.openLogBtnClick(Sender: Tobject);
var
  mask, fn: string;
  s: TfastStringAppend;
  i: integer;
begin
  mask := logSearchBox.text;
  s := TfastStringAppend.create;
  try
    if Sender = openLogBtn then
      s.append(logbox.text)
    else
      for i := 0 to logbox.lines.count - 1 do
        if fileMatch('*' + mask + '*', logbox.lines[i]) then
          s.append(logbox.lines[i] + CRLF);
    if s.length() = 0 then
    begin
      msgDlg('It''s empty', MB_ICONWARNING);
      exit;
    end;
    fn := saveTempFile(s.get());
  finally
    s.free
  end;
  if renameFile(fn, fn + '.txt') then
    exec(fn + '.txt')
  else
    msgDlg(MSG_NO_TEMP, MB_ICONERROR);
end;

procedure Tmainfrm.ipmenuclick(Sender: Tobject);
var
  ip: string;
begin
  ip := (Sender as TMenuItem).Caption;
  Delete(ip, pos('&', ip), 1);
  setDefaultIP(ip);
  searchbetteripChk.checked := FALSE;
  setClip(urlBox.text);
end; // ipmenuclick

// returns the last file added
function Tmainfrm.addFilesFromString(files: string;
  under: TtreeNode = NIL): Tfile;
var
  folderKindFrm: TfolderKindFrm;

  function selectFolderKind(): integer;
  begin
    application.restore();
    application.bringToFront();
    application.CreateForm(TfolderKindFrm, folderKindFrm);
    result := folderKindFrm.ShowModal();
    folderKindFrm.free;
  end; // selectFolderKind

const
  MSG1 = '%s item(s) already exists:'#13'%s'#13#13'Continue?';
  MAX_DUPE = 50;
var
  f: Tfile;
  kind, s, fn: string;
  doubles: TStringDynArray;
  res: integer;
  upload, skipComment: boolean;
begin
  result := NIL;
  if files = '' then
    exit;
  upload := FALSE;
  if singleLine(files) then
  begin
    files := trim(files);
    // this let me treat 'files' as a simple filename, not caring of the trailing CRLF

    // suggest template installation
    if (lowercase(ExtractFileExt(files)) = '.tpl') and
      (msgDlg('Install this template?', MB_YESNO) = MRYES) then
    begin
      setNewTplFile(files);
      exit;
    end;

    upload := (ipos('upload', extractFileName(files)) > 0) and
      (msgDlg('Do you want ANYONE to be able to upload to this folder?',
      MB_YESNO) = MRYES);
  end;
  // warn upon double filenames
  doubles := NIL;
  s := files;
  while s > '' do
  begin
    fn := chopLine(s);
    // we must resolve links here, or we may miss duplicates
    if isExtension(fn, '.lnk') or fileExists(fn + '\target.lnk') then
    // mod by mars
      fn := resolveLnk(fn);

    if (length(fn) = 3) and (fn[2] = ':') then
      fn := fn[1] + fn[2] // unit root folder
    else
      fn := extractFileName(fn);
    if existsNodeWithName(fn, under) then
      if addString(fn, doubles) > MAX_DUPE then
        break;
  end;
  if assigned(doubles) then
  begin
    filesbox.Repaint();
    res := length(doubles);
    s := if_(res > MAX_DUPE, intToStr(MAX_DUPE) + '+', intToStr(res));
    s := format(MSG1, [s, join(', ', doubles)]);
    if msgDlg(s, MB_ICONWARNING + MB_YESNO) <> IDYES then
      exit;
  end;

  f := NIL;
  skipComment := not singleLine(files);
  kind := if_(upload, 'real', addFolderDefault);
  addingItemsCounter := 0;
  try
    repeat
      fn := chopLine(files);
      if fn = '' then
        continue;
      f := Tfile.create(fn);
      if f.isFolder() then
      begin
        if kind = '' then
        begin // we didn't decide if real or virtual yet
          res := selectFolderKind();

          if isAbortResult(res) then
          begin
            f.free;
            exit;
          end;
          kind := if_(res = MRYES, 'virtual', 'real');
        end;

        if kind = 'virtual' then
          include(f.flags, FA_VIRTUAL);
      end;

      f.lock();
      try
        f.name := getUniqueNodeName(f.name, under);
        addFile(f, under, skipComment);
      finally
        f.unlock();
      end;

    until (files = '') or stopAddingItems;
  finally
    addingItemsCounter := -1
  end;

  if upload then
  begin
    addUniqueString(USER_ANYONE, f.accounts[FA_UPLOAD]);
    sortArray(f.accounts[FA_UPLOAD]);
  end;
  if assigned(f) and AutocopyURLonadditionChk.checked then
    setClip(f.fullURL());
  result := f;
end; // addFilesFromString

procedure Tmainfrm.addDropFiles(hnd: Thandle; under: TtreeNode);
var
  i, n: integer;
  buffer: array [0 .. 2000] of char;
  files: string;
begin
  if hnd = 0 then
    exit;
  GlobalLock(hnd);
  n := DragQueryFile(hnd, cardinal(-1), NIL, 0);
  files := '';
  buffer := '';
  for i := 0 to n - 1 do
  begin
    DragQueryFile(hnd, i, @buffer, SizeOf(buffer));
    files := files + buffer + CRLF;
  end;
  // DragFinish(hnd);  // this call seems to cause instability, don't know why
  GlobalUnlock(hnd);

  addFilesFromString(files, under);
end; // addDropFiles

procedure Tmainfrm.WMDropFiles(var msg: TWMDropFiles);
begin
  with filesbox.screenToClient(mouse.cursorPos) do
    addDropFiles(msg.Drop, filesbox.getNodeAt(x, y));
  inherited;
end; // WMDropFiles

procedure Tmainfrm.WMQueryEndSession(var msg: TWMQueryEndSession);
begin
  windowsShuttingDown := TRUE;
  quitting := TRUE;
  // in hard times, formClose() is not called (or not soon enough)
  quitASAP := TRUE;
  msg.result := 1;
  Close();
  inherited;
end; // WMQueryEndSession

procedure Tmainfrm.WMEndSession(var msg: TWMEndSession);
begin
  if msg.EndSession then
  begin
    windowsShuttingDown := TRUE;
    quitting := TRUE;
    quitASAP := TRUE;
    Close();
  end;
  inherited;
end; // WMEndSession

procedure Tmainfrm.WMNCLButtonDown(var msg: TWMNCLButtonDown);
begin
  if (msg.hitTest = Winapi.Windows.HTCLOSE) and trayInsteadOfQuitChk.checked
  then
  begin
    msg.hitTest := Winapi.Windows.HTCAPTION; // cancel closing
    minimizeToTray();
  end;
  inherited;
end;

procedure Tmainfrm.splitVMoved(Sender: Tobject);
begin
  if logbox.Width > 0 then
    lastGoodLogWidth := logbox.Width;
  filesBoxRatio := filesPnl.Width / clientWidth
end;

procedure Tmainfrm.appEventsShowHint(var HintStr: String; var CanShow: boolean;
  var HintInfo: THintInfo);

  function reduce(s: string): string;
  begin
    result := xtpl(s, [#13, ' ', #10, '']);
    if length(result) > 30 then
    begin
      setLength(result, 29);
      result := result + '...';
    end;
  end; // reduce

  function fileHint(): string;
  const
    INHERITED_LABEL = ' [inherited]';
    EXTERNAL_LABEL = ' [external]';
  var
    f, parent: Tfile;
    s, s2: string;
    inheritd, externl: boolean;

    function flag(lbl: string; att: TfileAttribute;
      positive: boolean = TRUE): string;
    begin
      result := if_((att in f.flags) = positive, #13 + lbl)
    end;

    function flagR(lbl: string; att: TfileAttribute;
      positive: boolean = TRUE): string;
    var
      inh: boolean;
    begin
      result := if_(f.hasRecursive(att, @inh), #13 + lbl);
      result := result + if_(inh, INHERITED_LABEL);
    end; // flagR

    procedure perm(action: TfileAction; msg: string);
    var
      s: string;
    begin
      s := join(', ', f.getAccountsFor(action, TRUE, @inheritd));
      if (s > '') and inheritd then
        s := s + INHERITED_LABEL;
      if s > '' then
        result := result + #13 + msg + ': ' + s;
    end;

  begin
    result := if_(HintsfornewcomersChk.checked, 'Drag your files here');
    f := pointedFile();
    if f = NIL then
      exit;
    parent := f.parent;

    result := 'URL: ' + f.url() + if_(f.isRealFolder() or f.isFile(),
      #13'Path: ' + f.resource);
    if f.isFile() then
      result := result + format(#13'Size: %s'#13'Downloads: %d',
        [smartsize(sizeOfFile(f.resource)), f.DLcount]);

    s := flagR('Invisible', FA_HIDDENTREE, TRUE);
    if s = '' then
      s := flag('Invisible', FA_HIDDEN);
    result := result + s + flag('Download forbidden', FA_DL_FORBIDDEN) +
      flagR('Don''t log', FA_DONT_LOG);

    if f.isFolder() then
    begin
      if assigned(parent) and parent.hasRecursive(FA_HIDE_EMPTY_FOLDERS) then
        result := result + #13'Hidden if empty' + INHERITED_LABEL;

      result := result + flag('Not browsable', FA_BROWSABLE, FALSE) +
        flag('Hide empty folders', FA_HIDE_EMPTY_FOLDERS) +
        flagR('Hide extention', FA_HIDE_EXT) + flagR('Archivable',
        FA_ARCHIVABLE)
    end;

    s := f.getRecursiveFileMask();
    if (s > '') and (f.defaultFileMask = '') then
      s := s + INHERITED_LABEL;
    if s > '' then
      result := result + #13'Default file mask: ' + s;

    perm(FA_ACCESS, 'Access for');
    if f.isRealFolder() then
      perm(FA_UPLOAD, 'Upload allowed for');
    perm(FA_DELETE, 'Delete allowed for');

    s := reduce(f.getDynamicComment());
    if (s > '') and (f.comment = '') then
      s := s + EXTERNAL_LABEL;
    if s > '' then
      result := result + #13'Comment: ' + s;

    s := reduce(f.getShownRealm());
    if (s > '') and (f.realm = '') then
      s := s + INHERITED_LABEL;
    if s > '' then
      result := result + #13'Realm: ' + s;

    s := reduce(f.getRecursiveDiffTplAsStr(@inheritd, @externl));
    if s > '' then
    begin
      if inheritd then
        s := s + INHERITED_LABEL;
      if externl then
        s := s + EXTERNAL_LABEL;
      result := result + #13'Diff template: ' + s;
    end;

    f.getFiltersRecursively(s, s2);
    result := result + if_(s > '', #13'Files filter: ' + s +
      if_(f.filesFilter = '', INHERITED_LABEL)) +
      if_(s2 > '', #13'Folders filter: ' + s2 + if_(f.foldersFilter = '',
      INHERITED_LABEL)) + if_(f.uploadFilterMask > '',
      #13'Upload filter: ' + f.uploadFilterMask) +
      flag('Don''t consider as download', FA_DONT_COUNT_AS_DL) +
      if_(f.dontCountAsDownloadMask > '',
      #13'Don''t consider as download (mask): ' + f.dontCountAsDownloadMask)
  end; // filehint

  function connHint(): string;
  var
    cd: TconnData;
  begin
    cd := pointedConnection();
    result := if_(HintsfornewcomersChk.checked,
      'This box shows info about current connections');
    if cd = NIL then
      exit;
    result := 'Connection time: ' + datetimeToStr(cd.time) +
      #13'Last request time: ' + datetimeToStr(cd.requestTime) + #13'Agent: ' +
      first(cd.agent, '<unknown>');
  end;

begin
  if HintInfo.HintControl = filesbox then
  begin
    HintInfo.ReshowTimeout := 800;
    HintStr := fileHint();
  end;
  if HintInfo.HintControl = connBox then
  begin
    HintInfo.ReshowTimeout := 800;
    HintStr := connHint();
  end;

  if not HintsfornewcomersChk.checked and
    ((HintInfo.HintControl = modeBtn) or (HintInfo.HintControl = menuBtn) or
    (HintInfo.HintControl = graphBox)) then
    HintStr := '';
  HintStr := chop(#0, HintStr);
  // info past null char are used for extra data storing
  CanShow := HintStr > '';
end;

procedure Tmainfrm.logmenuPopup(Sender: Tobject);
begin
  Readonly1.checked := logbox.readonly;
  Readonly1.visible := not easyMode;
  Banthisaddress1.visible := logbox.SelAttributes.color = ADDRESS_COLOR;
  Address2name1.visible := not easyMode;
  Logfile1.visible := not easyMode;
  logOnVideoChk.visible := not easyMode;
  Donotlogaddress1.visible := not easyMode;
  Clearandresettotals1.visible := not easyMode;
  Addresseseverconnected1.visible := not easyMode;
  Maxlinesonscreen1.visible := not easyMode;
  Dontlogsomefiles1.visible := not easyMode;
  Apachelogfileformat1.visible := not easyMode and (logFile.filename > '');
  tabOnLogFileChk.visible := not easyMode and (logFile.filename > '');
end;

function Tmainfrm.searchLog(dir: integer): boolean;
var
  t, s: string;
  i, l, tl, from, n: integer;
begin
  timeTookToSearchLog := now();
  try
    result := TRUE;
    from := logbox.selstart + 1;
    t := ansiLowerCase(logbox.text);
    s := ansiLowerCase(logSearchBox.text);
    if s = '' then
      exit;
    result := FALSE;
    if t = '' then
      exit;
    tl := length(t);
    // if we are typing (dir=0) then before search forward, see if we can extend the current selection
    if dir <> 0 then
      l := 0
    else
      l := match(pchar(s), @t[from], FALSE, [#13, #10]);
    if l > 0 then
      i := from
      // if he doesn't use wildcards, use posEx(), it should be much faster on a long text
    else if pos('?', s) + pos('*', s) = 0 then
    begin
      if dir <= 0 then
      begin
        s := reverseString(s);
        t := reverseString(t);
        from := tl - from + 1;
      end;
      i := posEx(s, t, from + 1);
      if i = 0 then
        i := pos(s, t);
      if i = 0 then
        exit;
      l := length(s);
      if dir <= 0 then
        i := tl - i - l + 2;
    end
    else // it's using wildcards, so use match(), but don't allow matching across different lines, or a search with a * may take forever
    begin
      if dir = 0 then
        dir := -1;
      inc(from, dir);
      i := from + dir;
      n := 0;
      s := trim2(s, ['*', ' ']);
      repeat
        l := match(pchar(s), @t[i], FALSE, [#13, #10]);
        if l > 0 then
          break;
        inc(i, dir);
        inc(n);
        if n >= tl then
          exit;
        if i > tl then
          i := 1;
        if i = 0 then
          i := tl;
      until FALSE;
    end;
    logbox.selstart := i - 1;
    logbox.SelLength := l;
    result := TRUE;
  finally
    timeTookToSearchLog := now() - timeTookToSearchLog
  end;
end;

procedure Tmainfrm.logSearchBoxChange(Sender: Tobject);
begin
  // from when he stopped typing, wait twice the time of a searching, but max 2 seconds
  searchLogTime := now() + min(timeTookToSearchLog * 2, 2 / SECONDS);
  openFilteredLog.enabled := logSearchBox.text > '';
end;

procedure Tmainfrm.logSearchBoxKeyPress(Sender: Tobject; var Key: char);
begin
  if Key = #13 then
  begin
    searchLog(-1);
    Key := #0;
  end;
end;

procedure Tmainfrm.logUpDownClick(Sender: Tobject; Button: TUDBtnType);
begin
  searchLog(if_(Button = btNext, -1, +1))
end;

procedure Tmainfrm.Readonly1Click(Sender: Tobject);
begin
  with logbox do
    ReadOnly := not ReadOnly
end;

procedure Tmainfrm.Clear1Click(Sender: Tobject);
begin
  logbox.clear()
end;

procedure Tmainfrm.Clearandresettotals1Click(Sender: Tobject);
begin
  logbox.clear();
  resetTotals();
end;

procedure Tmainfrm.Copy1Click(Sender: Tobject);
begin
  if logbox.SelLength > 0 then
    setClip(logbox.SelText)
  else
    setClip(logbox.text)
end;

procedure Tmainfrm.Saveas1Click(Sender: Tobject);
var
  fn: string;
begin
  fn := '';
  if PromptForFileName(fn, 'Text file|*.txt', 'txt', 'Save log', '', TRUE) then
    saveFile(fn, logbox.text);
end;

procedure Tmainfrm.Save1Click(Sender: Tobject);
begin
  saveFile('hfs.log', logbox.text)
end;

procedure deleteCFG();
begin
  deleteFile(lastUpdateCheckFN);
  deleteFile(cfgPath + CFG_FILE);
  deleteRegistry(CFG_KEY);
  deleteRegistry(CFG_KEY, HKEY_LOCAL_MACHINE);
end; // deleteCFG

procedure Tmainfrm.Clearoptionsandquit1click(Sender: Tobject);
begin
  deleteCFG();
  autosaveoptionsChk.checked := FALSE;
  Close();
end;

procedure Tmainfrm.collapseBtnClick(Sender: Tobject);
begin
  setLogToolbar(FALSE)
end;

function ListView_GetSubItemRect(lv: TlistView;
  iItem, iSubItem: integer): Trect;
const
  LVM_FIRST = $1000; { ListView messages }
  LVM_GETSUBITEMRECT = LVM_FIRST + 56;
begin
  result.top := iSubItem;
  result.left := 0;
  if sendMessage(lv.Handle, LVM_GETSUBITEMRECT, iItem, Longint(@result)) = 0
  then
    result.top := -1
end;

procedure Tmainfrm.connBoxAdvancedCustomDrawSubItem(Sender: TCustomListView;
  Item: TlistItem; SubItem: integer; state: TCustomDrawState;
  Stage: TCustomDrawStage; var DefaultDraw: boolean);
var
  r: Trect;
  cnv: Tcanvas;

  procedure textCenter(s: string);
  var
    i: integer;
  begin
    i := ((r.bottom - r.top) - cnv.textHeight(s)) div 2;
    // vertical margin, to center vertically
    inc(r.top, i);
    drawCentered(cnv, r, s);
    dec(r.top, i);
  end; // textCentered

  procedure drawProgress(now, total, lowerbound, upperbound: int64);
  var
    d: real;
    Selected: boolean;
    r1: Trect;
    x: integer;
    colors: array [boolean] of Tcolor;
  begin
    if (total <= 0) or (lowerbound >= upperbound) then
      exit;
    colors[FALSE] := clWindow;
    colors[TRUE] := blend(clWindow, clWindowText, 0.25);
    Selected := cdsSelected in state;
    r1 := rect(r.left + 1, r.top + 1, r.Right - 1, r.bottom - 1);
    // paint a shadow for non requested piece of data
    cnv.Brush.color := blend(clWindow, clHotLight, 0.30);
    cnv.Brush.Style := bsSolid;
    cnv.FillRect(r1);
    // and shrink the rectangle
    x := r1.Right - r1.left;
    cnv.pen.color := colors[Selected];
    cnv.pen.Style := psSolid;
    if lowerbound > 0 then
    begin
      inc(r1.left, round(x * lowerbound / total));
      cnv.MoveTo(r1.left - 1, r1.top);
      cnv.LineTo(r1.left - 1, r1.bottom);
    end;
    if upperbound > 0 then
      dec(r1.Right, round(x * (total - upperbound) / total));
    // border + non filled part
    cnv.Brush.color := colors[not Selected];
    cnv.Brush.Style := bsSolid;
    cnv.FillRect(r1);
    // filled part
    d := now / (upperbound - lowerbound);
    if d > 1 then
      d := 1;
    inc(r1.left, 1 + round(d * (r1.Right - r1.left - 2)));
    dec(r1.Right);
    dec(r1.bottom);
    inc(r1.top);
    cnv.Brush.color := colors[Selected];
    if not IsRectEmpty(r1) then
      cnv.FillRect(r1);
    // label
    cnv.Font.name := 'Small Fonts';
    cnv.Font.size := 7;
    cnv.Font.color := clWindowText;
    SetBkMode(cnv.Handle, Transparent);
    inc(r.top);
    textCenter(format('%d%%', [trunc(d * 100)]));
  end; // drawProgress

var
  cd: TconnData;
begin
  if SubItem <> 5 then
    exit;
  cd := conn2data(Item);
  if cd = NIL then
    exit;
  cnv := connBox.Canvas;
  r := ListView_GetSubItemRect(connBox, Item.index, SubItem);
  if isSendingFile(cd) or (cd.conn.reply.bodyMode = RBM_STREAM) then
    drawProgress(cd.conn.bytesSentLastItem, cd.conn.bytesFullBody,
      cd.conn.reply.firstByte, cd.conn.reply.lastByte)
  else if isReceivingFile(cd) then
    drawProgress(cd.conn.bytesPosted, cd.conn.post.length, 0,
      cd.conn.post.length);
end;

procedure Tmainfrm.connBoxData(Sender: Tobject; Item: TlistItem);
const
  HCS2STR: array [ThttpConnState] of string = ('idle', 'requesting',
    'receiving', 'thinking', 'replying', 'sending', 'disconnected');
var
  data: TconnData;

  function getFname(): string;
  begin
    if isSendingFile(data) then
      result := data.lastFN
    else if isReceivingFile(data) then
      result := data.uploadSrc
    else
      result := '-'
  end;

  function getStatus(): string;
  begin
    if isSendingFile(data) then
    begin
      if data.conn.paused then
        result := 'paused'
      else
        result := format('%s / %s sent', [dotted(data.conn.bytesSentLastItem),
          dotted(data.conn.bytesPartial)]);
      exit;
    end;
    if isReceivingFile(data) then
    begin
      result := format('%s / %s received', [dotted(data.conn.bytesPosted),
        dotted(data.conn.post.length)]);
      exit;
    end;
    result := HCS2STR[data.conn.state] + if_(data.conn.state = HCS_IDLE,
      ' ' + intToStr(data.conn.requestCount))
  end; // getStatus

  function getSpeed(): string;
  var
    d: real;
  begin
    case data.conn.state of
      HCS_REPLYING_BODY:
        d := data.conn.speedOut;
      HCS_POSTING:
        d := data.conn.speedIn;
    else
      d := data.averageSpeed;
    end;
    if d < 1 then
      result := '-'
    else
      result := format('%.1f KB/s', [d / 1000])
  end; // getSpeed

var
  progress: real;
begin
  if quitting then
    exit;
  if Item = NIL then
    exit;
  data := conn2data(Item);
  if data = NIL then
    exit;
  Item.Caption := nonEmptyConcat('', data.usr, '@') + data.address + ':' +
    data.conn.port;
  while Item.subitems.count < 5 do
    Item.subitems.add('');

  Item.Imageindex := -1;
  progress := -1;
  if data.conn.state = HCS_DISCONNECTED then
    Item.Imageindex := 21
  else if isSendingFile(data) then
  begin
    Item.Imageindex := 32;
    progress := data.conn.bytesSentLastItem / data.conn.bytesPartial;
  end
  else if isReceivingFile(data) then
  begin
    Item.Imageindex := 33;
    progress := data.conn.bytesPosted / data.conn.post.length;
  end;

  Item.subitems[0] := getFname();
  Item.subitems[1] := getStatus();
  Item.subitems[2] := getSpeed();
  Item.subitems[3] := getETA(data);
  Item.subitems[4] := if_(progress < 0, '',
    format('%d%%', [trunc(progress * 100)]));
end;

function Tmainfrm.appEventsHelp(Command: word; data: integer;
  var CallHelp: boolean): boolean;
begin
  CallHelp := FALSE; // avoid exception to be thrown
  result := FALSE;
end;

procedure Tmainfrm.appEventsMinimize(Sender: Tobject);
begin
  if not MinimizetotrayChk.checked then
    exit;
  minimizeToTray();
end;

procedure Tmainfrm.appEventsRestore(Sender: Tobject);
begin
  trayed := FALSE;
  if not showmaintrayiconChk.checked then
    tray.hide();
end;

procedure Tmainfrm.trayEvent(Sender: Tobject; ev: TtrayEvent);
begin
  updateTrayTip();
  if userInteraction.disabled then
    exit;
  case ev of
    TE_RCLICK:
      begin
        setForegroundWindow(Handle);
        // application.bringToFront() will act up when the window is minimized: the popped up menu will stay up forever
        with mouse.cursorPos do
          menu.popup(x, y);
      end;
    TE_CLICK:
      application.bringToFront();
    TE_2CLICK:
      begin
        application.restore();
        application.bringToFront();
      end;
  end;
end; // trayEvent

procedure Tmainfrm.trayiconforeachdownload1Click(Sender: Tobject);
begin
  trayfordownloadChk.checked := FALSE
end;

procedure Tmainfrm.downloadTrayEvent(Sender: Tobject; ev: TtrayEvent);
var
  i: integer;
begin
  if userInteraction.disabled then
    exit;

  for i := connBox.items.count - 1 downto 0 do
    if conn2data(i) = (Sender as TmyTrayIcon).data then
      connBox.itemIndex := i;

  case ev of
    TE_CLICK, TE_RCLICK:
      try
        fromTray := TRUE;
        with mouse.cursorPos do
          connmenu.popup(x, y);
      finally
        fromTray := FALSE
      end;
    TE_2CLICK:
      begin
        application.restore();
        application.bringToFront();
        connBox.setFocus();
      end;
  end;
end; // downloadtrayEvent

function Tmainfrm.getTrayTipMsg(tpl: string = ''): string;
begin
  if quitting or (rootFile = NIL) then
  begin
    result := '';
    exit;
  end;
  result := xtpl(first(tpl, trayMsg), ['%uptime%', uptimestr(), '%url%',
    rootFile.fullURL(), '%ip%', defaultIP, '%port%', srv.port, '%hits%',
    intToStr(hitsLogged), '%downloads%', intToStr(downloadsLogged), '%uploads%',
    intToStr(uploadsLogged), '%version%', HFS.Consts.VERSION, '%build%', VERSION_BUILD]);
end; // getTrayTipMsg

procedure Tmainfrm.updateTrayTip();
begin
  tray.setTip(getTrayTipMsg())
end;

procedure Tmainfrm.Restore1Click(Sender: Tobject);
begin
  application.restore();
  application.bringToFront();
end;

procedure Tmainfrm.restoreCfgBtnClick(Sender: Tobject);
begin
  setCfg(backuppedCfg);
  backuppedCfg := '';
  restoreCfgBtn.hide();
  eventScriptsLast := 0;
  resetOptions1.enabled := TRUE;
end;

procedure Tmainfrm.Restoredefault1Click(Sender: Tobject);
begin
  if msgDlg('Continue?', MB_ICONQUESTION + MB_YESNO) = MRNO then
    exit;
  tplFilename := '';
  tplLast := -1;
  tplImport := TRUE;
  setStatusBarText('The template has been reset');
end;

procedure Tmainfrm.Reverttopreviousversion1Click(Sender: Tobject);
const
  fn = 'revert.bat';
  REVERT_BATCH = 'START %0:s /WAIT "%1:s" -q' + CRLF +
    'ping 127.0.0.1 -n 3 -w 1000> nul' + CRLF + 'DEL "%1:s"' + CRLF +
    'MOVE "%2:s' + PREVIOUS_VERSION + '" "%1:s"' + CRLF + 'START %0:s "%1:s"' +
    CRLF + 'DEL %%0' + CRLF;
begin
  try
    progFrm.show('Processing...');
    saveFile(fn, format(REVERT_BATCH, [if_(isNT(), '""'), paramStr(0),
      exePath]));
    execNew(fn);
  finally
    progFrm.hide()
  end;

end;

procedure Tmainfrm.Numberofcurrentconnections1Click(Sender: Tobject);
begin
  setTrayShows('connections')
end;

procedure Tmainfrm.NumberofdifferentIPaddresses1Click(Sender: Tobject);
begin
  setTrayShows('ips')
end;

procedure Tmainfrm.NumberofdifferentIPaddresseseverconnected1Click
  (Sender: Tobject);
begin
  setTrayShows('ips-ever')
end;

procedure Tmainfrm.Numberofloggeddownloads1Click(Sender: Tobject);
begin
  setTrayShows('downloads')
end;

procedure Tmainfrm.Numberofloggedhits1Click(Sender: Tobject);
begin
  setTrayShows('hits')
end;

procedure Tmainfrm.setTrayShows(s: string);
begin
  trayShows := s;
  repaintTray();
end; // setTrayShows

procedure Tmainfrm.Exit1Click(Sender: Tobject);
begin
  Close()
end;

procedure Tmainfrm.Extension1Click(Sender: Tobject);
begin
  defSorting := 'ext'
end;

procedure Tmainfrm.onDownloadChkClick(Sender: Tobject);
begin
  flashOn := 'download'
end;

procedure Tmainfrm.onconnectionChkClick(Sender: Tobject);
begin
  flashOn := 'connection'
end;

procedure Tmainfrm.never1Click(Sender: Tobject);
begin
  flashOn := ''
end;

procedure Tmainfrm.addTray();
begin
  repaintTray();
  tray.show();
end; // addTray

procedure Tmainfrm.Allowedreferer1Click(Sender: Tobject);
const
  msg = 'Leave empty to disable this feature.' +
    #13'Here you can specify a mask.' +
    #13'When a file is requested, if the mask doesn''t match the "Referer" HTTP field, the request is rejected.';
begin
  InputQuery('Allowed referer', msg, allowedReferer)
end;

// addtray

procedure Tmainfrm.FormShow(Sender: Tobject);
begin
  if trayed then
    showWindow(application.Handle, SW_HIDE);
  updateTrayTip();
  connBox.DoubleBuffered := TRUE;
end;

procedure Tmainfrm.filesBoxDragOver(Sender, Source: Tobject; x, y: integer;
  state: TDragState; var Accept: boolean);
const
  THRESHOLD = 10;
var
  src, dst: Tfile;
  i: integer;
begin
  scrollFilesBox := -1;
  if y < THRESHOLD then
    scrollFilesBox := SB_LINEUP;
  if filesbox.height - y < THRESHOLD then
    scrollFilesBox := SB_LINEDOWN;

  Accept := FALSE;
  if Sender <> Source then
    exit; // only move files within filesBox
  dst := pointedFile(FALSE);
  if assigned(dst) and not dst.isFolder() then
    dst := dst.parent;
  if dst = NIL then
    exit;
  for i := 0 to filesbox.SelectionCount - 1 do
    with nodeToFile(filesbox.selections[i]) do
      if isRoot() or isLocked() then
        exit;
  src := selectedFile;
  Accept := (dst <> src.parent) and (dst <> src);
end;

procedure Tmainfrm.filesBoxDragDrop(Sender, Source: Tobject; x, y: integer);
var
  dst: TtreeNode;
  i, bak: integer;
  nodes: array of TtreeNode;
begin
  if selectedFile = NIL then
    exit;
  VFSmodified := TRUE;
  dst := filesbox.dropTarget;
  if not nodeToFile(dst).isFolder() then
    dst := dst.parent;
  // copy list of selected nodes
  setLength(nodes, filesbox.SelectionCount);
  for i := 0 to filesbox.SelectionCount - 1 do
    nodes[i] := filesbox.selections[i];
  // check for namesakes
  for i := 0 to length(nodes) - 1 do
    if existsNodeWithName(nodes[i].text, dst) then
      if msgDlg(MSG_SAME_NAME, MB_ICONWARNING + MB_YESNO) = IDYES then
        break
      else
        exit;
  // move'em
  for i := 0 to length(nodes) - 1 do
  begin
    // removing and restoring stateIndex is a workaround to a delphi bug
    bak := nodes[i].stateIndex;
    nodes[i].stateIndex := 0;
    nodes[i].MoveTo(dst, naAddChild);
    nodes[i].stateIndex := bak;
  end;
  filesbox.refresh();
  dst.AlphaSort(FALSE);
end;

procedure Tmainfrm.refreshConn(conn: TconnData);
var
  r: Trect;
  i: integer;
begin
  if quitting then
    exit;

  for i := 0 to connBox.items.count - 1 do
    if conn2data(i) = conn then
    begin
      connBoxData(connBox, connBox.items[i]);
      r := connBox.items[i].displayRect(drBounds);
      invalidateRect(connBox.Handle, @r, TRUE);
      break;
    end;
  // updateSbar();   // this was causing too many refreshes on fast connections
end; // refreshConn

const
  // IDs used for file chunks
  FK_HEAD = 0;
  FK_RESOURCE = 1;
  FK_NAME = 2;
  FK_FLAGS = 3;
  FK_NODE = 4;
  FK_FORMAT_VER = 5;
  FK_CRC = 6;
  FK_COMMENT = 7;
  FK_USERPWD = 8;
  FK_ADDEDTIME = 9;
  FK_DLCOUNT = 10;
  FK_ROOT = 11;
  FK_ACCOUNTS = 12;
  FK_FILESFILTER = 13;
  FK_FOLDERSFILTER = 14;
  FK_ICON_GIF = 15;
  FK_REALM = 16;
  FK_UPLOADACCOUNTS = 17;
  FK_DEFAULTMASK = 18;
  FK_DONTCOUNTASDOWNLOADMASK = 19;
  FK_AUTOUPDATED_FILES = 20;
  FK_DONTCOUNTASDOWNLOAD = 21;
  FK_HFS_VER = 22;
  FK_HFS_BUILD = 23;
  FK_COMPRESSED_ZLIB = 24;
  FK_DIFF_TPL = 25;
  FK_UPLOADFILTER = 26;
  FK_DELETEACCOUNTS = 27;

function Tmainfrm.getVFS(node: TtreeNode = NIL): string;

  function getAutoupdatedFiles(): string;
  var
    i: integer;
    fn: string;
  begin
    result := '';
    i := 0;
    while i < autoupdatedFiles.count do
    begin
      fn := autoupdatedFiles[i];
      result := result + TLV(FK_NODE, TLV(FK_NAME, fn) + TLV(FK_DLCOUNT,
        str_(autoupdatedFiles.getInt(fn))));
      inc(i);
    end;
  end; // getAutoupdatedFiles

var
  i: integer;
  f: Tfile;
  commonFields, s: string;
begin
  if node = NIL then
    node := rootNode;
  if node = NIL then
    exit;
  f := nodeToFile(node);
  commonFields := TLV(FK_FLAGS, str_(f.flags)) + TLV_NOT_EMPTY(FK_RESOURCE,
    f.resource) + TLV_NOT_EMPTY(FK_COMMENT, f.comment) +
    if_(f.user > '', TLV(FK_USERPWD, base64encode(f.user + ':' + f.pwd))) +
    TLV_NOT_EMPTY(FK_ACCOUNTS, join(';', f.accounts[FA_ACCESS])) +
    TLV_NOT_EMPTY(FK_UPLOADACCOUNTS, join(';', f.accounts[FA_UPLOAD])) +
    TLV_NOT_EMPTY(FK_DELETEACCOUNTS, join(';', f.accounts[FA_DELETE])) +
    TLV_NOT_EMPTY(FK_FILESFILTER, f.filesFilter) +
    TLV_NOT_EMPTY(FK_FOLDERSFILTER, f.foldersFilter) + TLV_NOT_EMPTY(FK_REALM,
    f.realm) + TLV_NOT_EMPTY(FK_DEFAULTMASK, f.defaultFileMask) +
    TLV_NOT_EMPTY(FK_UPLOADFILTER, f.uploadFilterMask) +
    TLV_NOT_EMPTY(FK_DONTCOUNTASDOWNLOADMASK, f.dontCountAsDownloadMask) +
    TLV_NOT_EMPTY(FK_DIFF_TPL, f.diffTpl);

  result := '';
  if f.isRoot() then
    result := result + TLV(FK_ROOT, commonFields);
  for i := 0 to node.count - 1 do
    result := result + getVFS(node.Item[i]); // recursion
  if f.isRoot() then
  begin
    result := result + TLV_NOT_EMPTY(FK_AUTOUPDATED_FILES,
      getAutoupdatedFiles());
    exit;
  end;
  if not f.isFile() then
    s := ''
  else
    s := TLV(FK_DLCOUNT, str_(f.DLcount));
  // called on a folder would be recursive

  // for non-root nodes, subnodes must be calculated first, so to be encapsulated
  result := TLV(FK_NODE, commonFields + TLV_NOT_EMPTY(FK_NAME, f.name) +
    TLV(FK_ADDEDTIME, str_(f.atime)) + TLV_NOT_EMPTY(FK_ICON_GIF,
    pic2str(f.icon)) + s + result // subnodes
    );
end; // getVFS

procedure Tmainfrm.setVFS(vfs: string; node: TtreeNode = NIL);
const
  MSG_BETTERSTOP = #13'Going on may lead to problems.' +
    #13'It is adviced to stop loading.' + #13'Stop?';
  MSG_BADCRC = 'This file is corrupted (CRC).';
  MSG_NEWER =
    'This file has been created with a newer and incompatible version.';
  MSG_ZLIB = 'This file is corrupted (ZLIB).';
  MSG_BAKAVAILABLE =
    'This file is corrupted but a backup is available.'#13'Continue with backup?';

var
  data: string;
  f: Tfile;
  after: record resetLetBrowse: boolean;
end;
act:
TfileAction;
TLV:
Ttlv;

procedure parseAutoupdatedFiles(data: string);
var
  s, fn: string;
begin
  autoupdatedFiles.clear();
  TLV.down();
  while TLV.pop(s) = FK_NODE do
  begin
    TLV.down();
    while not TLV.isOver() do
      case TLV.pop(s) of
        FK_NAME:
          fn := s;
        FK_DLCOUNT:
          autoupdatedFiles.setInt(fn, int_(s));
      end;
    TLV.up();
  end;
  TLV.up();
end; // parseAutoupdatedFiles

begin
  if vfs = '' then
    exit;
  if node = NIL then
  // this is supposed to be always true when loading a vfs, and never recurring
  begin
    node := rootNode;
    uploadPaths := NIL;
    usersInVFS.reset();
    if isAnyMacroIn(vfs) then
      loadingVFS.macrosFound := TRUE;
  end;
  fillChar(after, SizeOf(after), 0);
  node.DeleteChildren();
  f := Tfile(node.data);
  f.node := node;
  TLV := Ttlv.create;
  TLV.parse(vfs);
  while not TLV.isOver() do
    case TLV.pop(data) of
      FK_ROOT:
        begin
          setVFS(data, rootNode);
          if loadingVFS.build < '109' then
            include(f.flags, FA_ARCHIVABLE);
        end;
      FK_NODE:
        begin
          if progFrm.cancelRequested then
            exit;
          if progFrm.visible then
          begin
            progFrm.progress := TLV.getPerc();
            application.ProcessMessages();
          end;
          setVFS(data, addFile(Tfile.create(''), node, TRUE).node);
        end;
      FK_COMPRESSED_ZLIB:
        { Explanation for the #0 workaround.
          { I found an uncompressable vfs file, with ZDecompressStr2() raising an exception.
          { In the end i found it was missing a trailing #0, maybe do to an incorrect handling of strings
          { containing a trailing #0. You know, being using a zlib wrapper there is some underlying C code.
          { I was unable to reproduce the bug, but i found that correct data doesn't complain if i add an extra #0. }
        try
          data := ZDecompressStr2(data + #0, 31);
          if isAnyMacroIn(data) then
            loadingVFS.macrosFound := TRUE;
          setVFS(data, node);
        except
          msgDlg(MSG_ZLIB, MB_ICONERROR)
        end;
      FK_FORMAT_VER:
        begin
          if length(data) < 4 then // early versions: '1.0', '1.1'
          begin
            loadingVFS.resetLetBrowse := TRUE;
            after.resetLetBrowse := TRUE;
          end;
          if (int_(data) > CURRENT_VFS_FORMAT) and
            (msgDlg(MSG_NEWER + MSG_BETTERSTOP, MB_ICONERROR + MB_YESNO) = IDYES)
          then
            exit;
        end;
      FK_CRC:
        if str_(getCRC(TLV.getTheRest())) <> data then
        begin
          if loadingVFS.bakAvailable then
            if msgDlg(MSG_BAKAVAILABLE, MB_ICONWARNING + MB_YESNO) = IDYES then
            begin
              loadingVFS.useBackup := TRUE;
              exit;
            end;
          if msgDlg(MSG_BADCRC + MSG_BETTERSTOP, MB_ICONERROR + MB_YESNO) = IDYES
          then
            exit;
        end;
      FK_RESOURCE:
        f.resource := data;
      FK_NAME:
        begin
          f.name := data;
          node.text := data;
        end;
      FK_FLAGS:
        move(data[1], f.flags, length(data));
      FK_ADDEDTIME:
        f.atime := dt_(data);
      FK_COMMENT:
        f.comment := data;
      FK_USERPWD:
        begin
          data := base64decode(data);
          f.user := chop(':', data);
          f.pwd := data;
          usersInVFS.track(f.user, f.pwd);
        end;
      FK_DLCOUNT:
        f.DLcount := int_(data);
      FK_ACCOUNTS:
        f.accounts[FA_ACCESS] := split(';', data);
      FK_UPLOADACCOUNTS:
        f.accounts[FA_UPLOAD] := split(';', data);
      FK_DELETEACCOUNTS:
        f.accounts[FA_DELETE] := split(';', data);
      FK_FILESFILTER:
        f.filesFilter := data;
      FK_FOLDERSFILTER:
        f.foldersFilter := data;
      FK_UPLOADFILTER:
        f.uploadFilterMask := data;
      FK_REALM:
        f.realm := data;
      FK_DEFAULTMASK:
        f.defaultFileMask := data;
      FK_DIFF_TPL:
        f.diffTpl := data;
      FK_DONTCOUNTASDOWNLOADMASK:
        f.dontCountAsDownloadMask := data;
      FK_DONTCOUNTASDOWNLOAD:
        if boolean(data[1]) then
          include(f.flags, FA_DONT_COUNT_AS_DL); // legacy, now moved into flags
      FK_ICON_GIF:
        if data > '' then
          f.setupImage(str2pic(data));
      FK_AUTOUPDATED_FILES:
        parseAutoupdatedFiles(data);
      FK_HFS_BUILD:
        loadingVFS.build := data;
      FK_HEAD, FK_HFS_VER:
        ; // recognize these fields, but do nothing
    else
      loadingVFS.unkFK := TRUE;
    end;
  freeAndNIL(TLV);
  // legacy: in build #213 special usernames renamed for uniformity, and usernames are now sorted for faster access
  for act := low(act) to high(act) do
    if loadingVFS.build < '213' then
    begin
      replaceString(f.accounts[act], '*', USER_ANYONE);
      replaceString(f.accounts[act], '*+', USER_ANY_ACCOUNT);
      uniqueStrings(f.accounts[act]);
      sortArray(f.accounts[act]);
      // for a little time, we tried to replace anyone with any+anon. it was a failed and had to revert.
      if stringExists(loadingVFS.build, ['211', '212']) and
        stringExists(USER_ANY_ACCOUNT, f.accounts[act]) and
        stringExists(USER_ANONYMOUS, f.accounts[act]) then
      begin
        removeString(USER_ANY_ACCOUNT, f.accounts[act]);
        replaceString(f.accounts[act], USER_ANONYMOUS, USER_ANYONE);
      end;
    end;

  if FA_VIS_ONLY_ANON in f.flags then
    loadingVFS.visOnlyAnon := TRUE;
  if f.isVirtualFolder() or f.isLink() then
    f.mtime := f.atime;
  if assigned(f.accounts[FA_UPLOAD]) and (f.resource > '') then
    addString(f.resource, uploadPaths);
  f.setupImage();
  if after.resetLetBrowse then
    f.recursiveApply(setBrowsable, integer(FA_BROWSABLE in f.flags));
end; // setVFS

function addVFSheader(vfsdata: string): string;
begin
  if length(vfsdata) > COMPRESSION_THRESHOLD then
    vfsdata := TLV(FK_COMPRESSED_ZLIB, ZcompressStr2(vfsdata, zcFastest, 31, 8,
      zsDefault));
  result := TLV(FK_HEAD, VFS_FILE_IDENTIFIER) + TLV(FK_FORMAT_VER,
    str_(CURRENT_VFS_FORMAT)) + TLV(FK_HFS_VER, HFS.Consts.VERSION) +
    TLV(FK_HFS_BUILD, VERSION_BUILD) + TLV(FK_CRC, str_(getCRC(vfsdata)));
  // CRC must always be right before data
  result := result + vfsdata
end; // addVFSheader

procedure Tmainfrm.Savefilesystem1Click(Sender: Tobject);
begin
  saveVFS()
end;

procedure Tmainfrm.filesBoxDeletion(Sender: Tobject; node: TtreeNode);
var
  f: Tfile;
begin
  f := node.data;
  node.data := NIL;
  // the test on uploadPaths may save some function call
  if assigned(f.accounts[FA_UPLOAD]) and assigned(uploadPaths) then
    removeString(f.resource, uploadPaths);
  try
    f.free
  except
  end;
  if node = rootNode then
    rootNode := NIL;
  VFSmodified := TRUE
end;

function blockLoadSave(): boolean;
begin
  result := addingItemsCounter > 0;
  if not result then
    exit;
  msgDlg('Cannot load or save while adding files', MB_ICONERROR);
end; // blockLoadSave

procedure Tmainfrm.Loadfilesystem1Click(Sender: Tobject);
var
  fn: string;
begin
  if blockLoadSave() then
    exit;
  if not checkVfsOnQuit() then
    exit;
  fn := '';
  if PromptForFileName(fn, 'VirtualFileSystem|*.vfs', 'vfs', 'Open VFS file')
  then
    loadVFS(fn);
end;

procedure Tmainfrm.leavedisconnectedconnectionsChkClick(Sender: Tobject);
var
  i: integer;
  data: TconnData;
begin
  if leavedisconnectedconnectionsChk.checked then
    exit;
  i := 0;
  while i < connBox.items.count do
  begin
    data := conn2data(i);
    if data.conn.state = HCS_DISCONNECTED then
    begin
      toDelete.add(data);
      data.deleting := TRUE;
    end;
    inc(i);
  end;
  connBox.items.count := srv.conns.count;
end;

procedure drawGraphOn(cnv: Tcanvas; colors: TIntegerDynArray = NIL);
var
  i, h, maxV: integer;
  r: Trect;
  top: double;
  s: string;

  procedure drawSample(sample: integer);
  begin
    cnv.MoveTo(r.left + i, r.bottom);
    cnv.LineTo(r.left + i, r.bottom - 1 - sample * h div maxV);
  end; // drawSample

  function getColor(idx: integer; def: Tcolor): Tcolor;
  begin
    if (length(colors) <= idx) or (colors[idx] = clDefault) then
      result := def
    else
      result := colors[idx]
  end; // getColor

begin
  r := cnv.cliprect;
  // clear
  cnv.Brush.color := getColor(0, clBlack);
  cnv.FillRect(r);
  // draw grid
  cnv.pen.color := getColor(1, rgb(0, 0, 120));
  i := r.left;
  while i < r.Right do
  begin
    cnv.MoveTo(i, r.top);
    cnv.LineTo(i, r.bottom);
    inc(i, 10);
  end;
  i := r.bottom;
  while i > r.top do
  begin
    cnv.MoveTo(r.left, i);
    cnv.LineTo(r.Right, i);
    dec(i, 10);
  end;

  maxV := max(graph.maxV, 1);
  h := r.bottom - r.top - 1;
  // draw graph
  cnv.pen.color := getColor(2, clFuchsia);
  for i := 0 to (r.Right - r.left) - 1 do
    drawSample(graph.samplesOut[i]);
  cnv.pen.color := getColor(3, clYellow);
  for i := 0 to (r.Right - r.left) - 1 do
    drawSample(graph.samplesIn[i]);
  // text
  cnv.Font.color := getColor(4, clLtGray);
  cnv.Font.name := 'Small Fonts';
  cnv.Font.size := 7;
  SetBkMode(cnv.Handle, Transparent);
  top := (graph.maxV / 1000) * safeDiv(10.0, graph.rate);
  s := format('Top speed: %.1f KB/s    ---    %d kbps', [top, round(top * 8)]);
  cnv.TextOut(r.Right - cnv.TextWidth(s) - 20, 3, s);
  if assigned(globalLimiter) and (globalLimiter.maxSpeed < MAXINT) then
    cnv.TextOut(r.Right - 180 + 25, 15, format('Limit: %.1f KB/s',
      [globalLimiter.maxSpeed / 1000]));
end; // drawGraphOn

procedure Tmainfrm.graphBoxPaint(Sender: Tobject);
var
  bmp: Tbitmap;
  r: Trect;
begin
  if not graphBox.visible then
    exit;
  bmp := Tbitmap.create();
  bmp.Width := graphBox.Width;
  bmp.height := graphBox.height;
  r := bmp.Canvas.cliprect;
  drawGraphOn(bmp.Canvas);
  graphBox.Canvas.CopyRect(r, bmp.Canvas, r);
  bmp.free;
end;

function Tmainfrm.getGraphPic(cd: TconnData = NIL): string;
var
  bmp: Tbitmap;
  refresh: string;
  i: integer;
  colors: TIntegerDynArray;
  options: string;

  procedure addColor(c: Tcolor);
  var
    n: integer;
  begin
    n := length(colors);
    setLength(colors, n + 1);
    colors[n] := c;
  end; // addColor

begin
  options := copy(decodeURL(cd.conn.request.url), 12, MAXINT);
  Delete(options, pos('?', options), MAXINT);
  bmp := Tbitmap.create();
  bmp.Width := graphBox.Width;
  bmp.height := graphBox.height;
  colors := NIL;
  if options = '' then
  begin
    // here is an initial support for ?parameters. colors not supported yet.
    try
      bmp.Width := strToInt(cd.urlvars.values['w'])
    except
    end;
    try
      bmp.height := min(strToInt(cd.urlvars.values['h']),
        300000 div max(1, bmp.Width))
    except
    end;
    refresh := cd.urlvars.values['refresh'];
  end
  else
    try
      i := strToInt(chop('x', options));
      if (i > 0) and (i <= length(graph.samplesIn)) then
        bmp.Width := i;
      i := strToInt(chop('x', options));
      if (i > 0) and (i <= length(graph.samplesIn)) then
        bmp.height := min(i, 300000 div max(1, bmp.Width));
      refresh := chop('x', options);
      for i := 1 to 5 do
        addColor(stringToColorEx(chop('x', options), clDefault));
    except
    end;
  drawGraphOn(bmp.Canvas, colors);
  result := bmp2str(bmp);
  bmp.free;
  if cd = NIL then
    exit;
  cd.conn.addHeader('Cache-Control: no-cache');
  if refresh > '' then
    cd.conn.addHeader('Refresh: ' + refresh);
end; // getGraphPic

procedure resendShortcut(mi: TMenuItem; sc: Tshortcut);
var
  i: integer;
begin
  if mi.ShortCut = sc then
    mi.click();
  for i := 0 to mi.count - 1 do
    resendShortcut(mi.items[i], sc);
end;

procedure Tmainfrm.FormKeyDown(Sender: Tobject; var Key: word;
  Shift: TShiftState);
begin
  altPressedForMenu := (Key = 18) and (Shift = [ssAlt]);
  resendShortcut(menu.items, ShortCut(Key, Shift));
  if Shift = [] then
    case Key of
      VK_F10:
        popupMainMenu();
    end;
end;

procedure Tmainfrm.FormKeyUp(Sender: Tobject; var Key: word;
  Shift: TShiftState);
begin
  if altPressedForMenu and (Key = 18) and (Shift = []) then
    popupMainMenu();
  altPressedForMenu := FALSE
end;

procedure Tmainfrm.Officialwebsite1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/hfs/')
end;

procedure Tmainfrm.showmaintrayiconChkClick(Sender: Tobject);
begin
  if showmaintrayiconChk.checked then
    addTray()
  else
    tray.hide();
end;

function Shell_GetImageLists(var hl, HS: Thandle): boolean; stdcall;
  external 'shell32.dll' index 71;

function getSystemimages(): TImageList;
var
  hl, HS: Thandle;
begin
  result := NIL;
  if not Shell_GetImageLists(hl, HS) then
    exit;
  result := TImageList.create(NIL);
  result.ShareImages := TRUE;
  result.Handle := HS;
end; // loadSystemimages

procedure Tmainfrm.expandBtnClick(Sender: Tobject);
begin
  setLogToolbar(TRUE)
end;

procedure Tmainfrm.Speedlimit1Click(Sender: Tobject);
const
  msg = 'Max bandwidth (KB/s).'#13 + MSG_EMPTY_NO_LIMIT;
var
  s: string;
begin
  if speedLimit < 0 then
    s := ''
  else
    s := floatToStr(speedLimit);
  if InputQuery('Speed limit', msg, s) then
    try
      s := trim(s);
      if s = '' then
        setSpeedLimit(-1)
      else
        setSpeedLimit(strToFloat(s));
      if speedLimit = 0 then
        msgDlg('Zero is an effective limit.'#13'To disable instead, leave empty.',
          MB_ICONWARNING);
      // a manual set of speedlimit voids the pause command
      Pausestreaming1.checked := FALSE;
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

procedure Tmainfrm.Speedlimitforsingleaddress1Click(Sender: Tobject);
const
  msg = 'Max bandwidth for single address (KB/s).'#13 + MSG_EMPTY_NO_LIMIT;
var
  s: string;
begin
  if speedLimitIP <= 0 then
    s := ''
  else
    s := floatToStr(speedLimitIP);
  if InputQuery('Speed limit for single address', msg, s) then
    try
      s := trim(s);
      if s = '' then
        setSpeedLimitIP(-1)
      else
        setSpeedLimitIP(strToFloat(s));
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

procedure Tmainfrm.setNoDownloadTimeout(v: integer);
begin
  if v < 0 then
    v := 0;
  if v <> noDownloadTimeout then
    lastActivityTime := now();
  noDownloadTimeout := v;
  noDownloadTimeout1.Caption := 'No downloads timeout: ' +
    if_(v = 0, 'disabled', intToStr(v));
end;

procedure Tmainfrm.setGraphRate(v: integer);
const
  msg = 'Graph refresh rate: %d (tenths of second)';
begin
  if v < 1 then
    v := 1;
  if graph.rate = v then
    exit;
  graph.rate := v;
  Graphrefreshrate1.Caption := format(msg, [v]);
  // changing rate invalidates previous data
  fillChar(graph.samplesOut, SizeOf(graph.samplesOut), 0);
  fillChar(graph.samplesIn, SizeOf(graph.samplesIn), 0);
  graph.maxV := 0;
end; // setGraphRate

procedure Tmainfrm.Maxconnections1Click(Sender: Tobject);
const
  msg = 'Max simultaneous connections to serve.' +
    #13'Most people don''t know this function well, and have problems. If you are unsure, please use the "Max simultaneous downloads".'
    + #13 + MSG_EMPTY_NO_LIMIT;
  MSG2 = 'In this moment there are %d active connections';
var
  s: string;
begin
  if maxConnections > 0 then
    s := intToStr(maxConnections)
  else
    s := '';
  if InputQuery('Max connections', msg, s) then
    try
      setMaxConnections(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if (maxConnections > 0) and (srv.conns.count > maxConnections) then
    msgDlg(format(MSG2, [srv.conns.count]), MB_ICONWARNING);
end;

procedure Tmainfrm.maxDLs1Click(Sender: Tobject);
const
  msg = 'Max simultaneous downloads.'#13 + MSG_EMPTY_NO_LIMIT;
  MSG2 = 'In this moment there are %d active downloads';
var
  s: string;
  i: integer;
begin
  if maxContempDLs > 0 then
    s := intToStr(maxContempDLs)
  else
    s := '';
  if InputQuery('Max downloads', msg, s) then
    try
      setMaxDLs(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if maxContempDLs = 0 then
    exit;
  i := countDownloads();
  if i > maxContempDLs then
    msgDlg(format(MSG2, [i]), MB_ICONWARNING);
end;

procedure Tmainfrm.Maxconnectionsfromsingleaddress1Click(Sender: Tobject);
const
  msg = 'Max simultaneous connections to accept from a single IP address.' +
    #13'Most people don''t know this function well, and have problems. If you are unsure, please use the "Max simultaneous downloads from a single IP address".'
    + #13 + MSG_EMPTY_NO_LIMIT;
var
  s: string;
  addresses: TStringDynArray;
  i: integer;
begin
  if maxConnectionsIP > 0 then
    s := intToStr(maxConnectionsIP)
  else
    s := '';
  if InputQuery('Max connections by IP', msg, s) then
    try
      setMaxConnectionsIP(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if maxConnectionsIP = 0 then
    exit;
  addresses := NIL;
  for i := 0 to srv.conns.count - 1 do
    with conn2data(i) do
      if countConnectionsByIP(address) > maxConnectionsIP then
        addUniqueString(address, addresses);
  if assigned(addresses) then
    msgDlg(format(MSG_ADDRESSES_EXCEED, [join(#13, addresses)]),
      MB_ICONWARNING);
end;

procedure Tmainfrm.MaxDLsIP1Click(Sender: Tobject);
const
  msg = 'Max simultaneous downloads from a single IP address.' + #13 +
    MSG_EMPTY_NO_LIMIT;
var
  s: string;
  addresses: TStringDynArray;
  i: integer;
begin
  if maxContempDLsIP > 0 then
    s := intToStr(maxContempDLsIP)
  else
    s := '';
  if InputQuery('Max downloads by IP', msg, s) then
    try
      setMaxDLsIP(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if maxContempDLsIP = 0 then
    exit;
  addresses := NIL;
  for i := 0 to srv.conns.count - 1 do
    with conn2data(i) do
      if countDownloads(address) > maxContempDLsIP then
        addUniqueString(address, addresses);
  if assigned(addresses) then
    msgDlg(format(MSG_ADDRESSES_EXCEED, [join(#13, addresses)]),
      MB_ICONWARNING);
end;

procedure Tmainfrm.Forum1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/forum/')
end;

procedure Tmainfrm.FAQ1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/sw/?faq=hfs')
end;

procedure Tmainfrm.License1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/sw/license.txt')
end;

procedure Tmainfrm.pasteFiles();
begin
  // try twice
  try
    addDropFiles(clipboard.GetAsHandle(CF_HDROP), filesbox.Selected)
  except
    try
      addDropFiles(clipboard.GetAsHandle(CF_HDROP), filesbox.Selected)
    except
      on e: Exception do
        msgDlg(e.message, MB_ICONERROR);
    end
  end;
end;

procedure Tmainfrm.Paste1Click(Sender: Tobject);
begin
  pasteFiles()
end;

procedure Tmainfrm.Addfiles1Click(Sender: Tobject);
var
  dlg: TopenDialog;
  i: integer;
begin
  dlg := TopenDialog.create(self);
  if System.SysUtils.DirectoryExists(lastDialogFolder) then
    dlg.InitialDir := lastDialogFolder;
  dlg.options := dlg.options + [ofAllowMultiSelect, ofFileMustExist,
    ofPathMustExist];
  if dlg.Execute() then
  begin
    for i := 0 to dlg.files.count - 1 do
      addFile(Tfile.create(dlg.files[i]), filesbox.Selected,
        dlg.files.count <> 1);
    lastDialogFolder := extractFilePath(dlg.filename);
  end;
  dlg.free;
end;

procedure Tmainfrm.Addfolder1Click(Sender: Tobject);
begin
  if selectFolder('', lastDialogFolder) then
  begin
    addFilesFromString(lastDialogFolder, filesbox.Selected);
  end;
end;

procedure Tmainfrm.graphSplitterMoved(Sender: Tobject);
begin
  graph.size := graphBox.height
end;

procedure Tmainfrm.Graphrefreshrate1Click(Sender: Tobject);
var
  s: string;
begin
  s := intToStr(graph.rate);
  if InputQuery('Graph refresh rate', 'Tenths of second', s) then
    try
      s := trim(s);
      if s = '' then
        setGraphRate(10)
      else
        setGraphRate(strToInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

procedure Tmainfrm.Pausestreaming1Click(Sender: Tobject);
begin
  if Pausestreaming1.checked then
    globalLimiter.maxSpeed := 0
  else
    setSpeedLimit(speedLimit)
end;

procedure Tmainfrm.Comment1Click(Sender: Tobject);
var
  i: integer;
begin
  if selectedFile = NIL then
    exit;
  inputComment(selectedFile);
  for i := 0 to filesbox.SelectionCount - 1 do
    nodeToFile(filesbox.selections[i]).comment := selectedFile.comment;
end;

procedure Tmainfrm.filesBoxCustomDrawItem(Sender: TCustomTreeView;
  node: TtreeNode; state: TCustomDrawState; var DefaultDraw: boolean);
var
  f: Tfile;
  a: TStringDynArray;
  onlyAnon: boolean;
begin
  if not Sender.visible then
    exit;
  f := Tfile(node.data);
  if f = NIL then
    exit;
  if f.hasRecursive([FA_HIDDEN, FA_HIDDENTREE], TRUE) then
    with Sender.Canvas.Font do
      Style := Style + [fsItalic];
  a := f.accounts[FA_ACCESS];
  onlyAnon := onlyString(USER_ANONYMOUS, a);
  node.stateIndex := ifThen((f.user > '') or (assigned(a) and not onlyAnon),
    ICON_LOCK, -1);
end;

function Tmainfrm.fileAttributeInSelection(fa: TfileAttribute): boolean;
var
  i: integer;
begin
  for i := 0 to filesbox.SelectionCount - 1 do
    if fa in nodeToFile(filesbox.selections[i]).flags then
    begin
      result := TRUE;
      exit;
    end;
  result := FALSE;
end; // fileAttributeInSelection

procedure Tmainfrm.Setuserpass1Click(Sender: Tobject);
var
  i: integer;
  user, pwd: string;
  f: Tfile;
begin
  if selectedFile = NIL then
    exit;
  if fileAttributeInSelection(FA_LINK) and
    (msgDlg(MSG_UNPROTECTED_LINKS, MB_ICONWARNING + MB_YESNO) <> IDYES) then
    exit;
  user := selectedFile.user;
  pwd := selectedFile.pwd;
  if not newuserpassFrm.prompt(user, pwd) then
    exit;
  for i := 0 to filesbox.SelectionCount - 1 do
  begin
    f := filesbox.selections[i].data;
    usersInVFS.Drop(f.user, f.pwd);
    f.user := user;
    f.pwd := pwd;
    usersInVFS.track(f.user, f.pwd);
  end;
  filesbox.Repaint();
  VFSmodified := TRUE;
end;

procedure Tmainfrm.browseBtnClick(Sender: Tobject);
begin
  browse(urlBox.text)
end;

procedure Tmainfrm.BanIPaddress1Click(Sender: Tobject);
var
  cd: TconnData;
begin
  cd := selectedConnection();
  if cd = NIL then
    exit;
  banAddress(cd.address);
end;

procedure showOptions(page: TtabSheet);
var
  was: boolean;
begin
  optionsFrm.pageCtrl.ActivePage := page;
  was := page.TabVisible;
  page.TabVisible := TRUE;
  if mainfrm.modalOptionsChk.checked and not optionsFrm.visible then
    optionsFrm.ShowModal()
  else
    optionsFrm.show();
  page.TabVisible := was;
end;

procedure Tmainfrm.BannedIPaddresses1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.bansPage)
end;

procedure Tmainfrm.recentsClick(Sender: Tobject);
var
  i: integer;
begin
  if blockLoadSave() then
    exit;
  i := strToInt((Sender as TMenuItem).Caption[3]);
  if i > length(recentFiles) then
    exit;
  dec(i); // convert to zero based
  if fileExists(recentFiles[i]) then
  begin
    if not checkVfsOnQuit() then
      exit;
    loadVFS(recentFiles[i]);
  end
  else
  begin
    msgDlg('The file does not exist anymore', MB_ICONERROR);
    removeString(recentFiles, i);
    updateRecentFilesMenu();
  end;
end;

procedure Tmainfrm.updateRecentFilesMenu();
var
  i: integer;
begin
  Loadrecentfiles1.clear();
  for i := 0 to length(recentFiles) - 1 do
    Loadrecentfiles1.add(newItem('[&' + intToStr(i + 1) + '] ' +
      extractFileName(recentFiles[i]), 0, FALSE, TRUE, recentsClick, 0,
      'recent'));
  Loadrecentfiles1.visible := Loadrecentfiles1.count > 0;
end; // updateRecentFilesMenu

procedure Tmainfrm.loadVFS(fn: string);
const
  MSG_TITLE = 'Loading VFS';
  MSG_OLD = 'This file is old and uses different settings.' +
    #13'The "let browse" folder option will be reset.' +
    #13'Re-saving the file will update its format.';
  MSG_UNK_FK = 'This file has been created with a newer version.' +
    #13'Some data was discarded because unknown.' +
    #13'If you save the file now, the discarded data will NOT be saved.';
  MSG_VIS_ONLY_ANON =
    'This VFS file uses the "Visible only to anonymous users" feature.' +
    #13'This feature is not available anymore.' +
    #13'You can achieve similar results by restricting access to @anonymous,' +
    #13'then enabling "List protected items only for allowed users".';
  MSG_AUTO_DISABLED = 'Because of the problems encountered in loading,' +
    #13'automatic saving has been disabled' +
    #13'until you save manually or load another one.';
  MSG_CORRUPTED = 'This file does not contain valid data.';
  MSG_MACROS_FOUND = '!!!!!!!!! DANGER !!!!!!!!!' +
    #13'This file contains macros.' +
    #13'Don''t accept macros from people you don''t trust.' +
    #13#13'Trust this file?';
var
  took: Tdatetime;
  data: string;

  function anyAutosavingFeatureEnabled(): boolean;
  begin
    result := (autosaveVFS.every > 0) or autosaveVFSchk.checked
  end;

  function restoreBak(): boolean;
  begin
    result := fileExists(fn + BAK_EXT) and
      (not fileExists(fn) or renameFile(fn, fn + CORRUPTED_EXT)) and
      renameFile(fn + BAK_EXT, fn);
    if result then
      data := loadFile(fn);
  end; // restoreBak

begin
  if fn = '' then
    exit;
  filesbox.hide(); // it seems to speed up a lot
  progFrm.show('Loading VFS...', TRUE);
  disableUserInteraction();
  try
    fillChar(loadingVFS, SizeOf(loadingVFS), 0);
    took := now();
    data := loadFile(fn);
    loadingVFS.bakAvailable := fileExists(fn + BAK_EXT);
    if not ansiStartsStr(TLV(FK_HEAD, VFS_FILE_IDENTIFIER), data) and
      not restoreBak() then
    begin
      if data = '' then
        msgDlg(MSG_CORRUPTED, MB_ICONERROR);
      exit;
    end;
    try
      initVFS();
      setVFS(data);
      if loadingVFS.useBackup and restoreBak() then
      begin
        initVFS();
        setVFS(loadFile(fn));
      end;
      took := now() - took;
    finally
      if progFrm.cancelRequested then
        initVFS()
      else
        lastFileOpen := fn;
      VFSmodified := FALSE;
      purgeVFSaccounts(); // remove references to non-existent users
      filesbox.FullCollapse();
      rootNode.Selected := TRUE;
      rootNode.MakeVisible();
    end;
  finally
    reenableUserInteraction();
    progFrm.hide();
    filesbox.show();
  end;
  if progFrm.cancelRequested then
    exit;
  if loadingVFS.macrosFound and not stringExists(fn, trustedFiles) and
    (msgDlg(MSG_MACROS_FOUND, MB_ICONWARNING + MB_YESNO, MSG_TITLE) = MRNO) then
  begin
    initVFS();
    exit;
  end;
  addUniqueString(fn, trustedFiles);
  if loadingVFS.visOnlyAnon then
    msgDlg(MSG_VIS_ONLY_ANON, MB_ICONWARNING, MSG_TITLE);
  if loadingVFS.resetLetBrowse then
    msgDlg(MSG_OLD, MB_ICONWARNING, MSG_TITLE);
  if loadingVFS.unkFK then
    msgDlg(MSG_UNK_FK, MB_ICONWARNING, MSG_TITLE);

  with loadingVFS do
    disableAutosave := unkFK or resetLetBrowse or visOnlyAnon;
  if loadingVFS.disableAutosave and anyAutosavingFeatureEnabled() then
    msgDlg(MSG_AUTO_DISABLED, MB_ICONWARNING, MSG_TITLE);

  setStatusBarText(format('Loaded in %.1f seconds (%s)',
    [took * SECONDS, fn]), 10);

  removeString(fn, recentFiles); // avoid duplicates
  insertstring(fn, 0, recentFiles); // insert fn as first element
  removeString(recentFiles, MAX_RECENT_FILES, length(recentFiles));
  // shrink2max
  updateRecentFilesMenu();
end; // loadVFS

procedure Tmainfrm.logBoxChange(Sender: Tobject);
begin
  logToolbar.visible := not easyMode and (logbox.lines.count > 0)
end;

procedure Tmainfrm.logBoxMouseDown(Sender: Tobject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
begin
  if Button = mbRight then
    logRightClick := point(x, y);
end;

procedure Tmainfrm.popupMainMenu();
begin
  menuBtn.down := TRUE;
  with menuBtn.clientToScreen(point(0, menuBtn.height)) do
    menu.popup(x, y);
  menuBtn.down := FALSE;
end;

procedure Tmainfrm.portBtnClick(Sender: Tobject);
var
  s: string;
begin
  s := port;
  repeat
    if not InputQuery('Port',
      'Specify a port to accept connection,'#13'or leave empty to decide automatically.',
      s) then
      exit;
    s := trim(s);
    if not isOnlyDigits(s) then
    begin
      msgDlg('Numbers only', MB_ICONERROR);
      continue;
    end;
    if changePort(s) then
      exit;
    sayPortBusy(s);
  until FALSE;
end;

procedure Tmainfrm.updateAlwaysOnTop();
begin
  if alwaysontopChk.checked then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal
end; // updateAlwaysOnTop

procedure Tmainfrm.updateBtnClick(Sender: Tobject);
begin
  if now() - lastUpdateCheck > 1 * HOURS then
    autoCheckUpdates();
  // refresh update info, in case the button is clicked long after the check

  doTheUpdate(clearAndReturn(updateWaiting));
  updateBtn.hide();
end;

procedure Tmainfrm.Changeeditor1Click(Sender: Tobject);
begin
  selectFile(tplEditor, '', 'Programs|*.exe', [ofFileMustExist])
end;

procedure Tmainfrm.Changefile1Click(Sender: Tobject);
begin
  if selectFile(tplFilename, 'Change template file', 'Template file|*.tpl',
    [ofPathMustExist, ofCreatePrompt]) then
    setNewTplFile(tplFilename);
end;

procedure Tmainfrm.Changeport1Click(Sender: Tobject);
begin
  portBtnClick(portBtn)
end;

procedure Tmainfrm.Checkforupdates1Click(Sender: Tobject);
const
  MSG_INFO = 'Last stable version: %s'#13#13'Last untested version: %s'#13;
  MSG_NEWER = 'There''s a new version available online: %s';
var
  updateURL: string;
  info: TTemplate;
begin
  progFrm.show('Searching for updates...');
  try
    info := downloadUpdateInfo()
  finally
    progFrm.hide()
  end;

  if info = NIL then
  begin
    msgDlg(MSG_COMM_ERROR, MB_ICONERROR);
    exit;
  end;

  try
    msgDlg(format(MSG_INFO, [info['last stable'], first([info['last untested'],
      'none'])]));

    updateURL := '';
    if trim(info['last stable build']) > VERSION_BUILD then
    begin
      msgDlg(format(MSG_NEWER, [info['last stable']]));
      updateURL := trim(info['last stable url']);
    end
    else if (not VERSION_STABLE or testerUpdatesChk.checked) and
      (trim(info['last untested build']) > VERSION_BUILD) then
    begin
      msgDlg(format(MSG_NEWER, [info['last untested']]));
      updateURL := trim(info['last untested url']);
    end;

    msgDlg(info['notice'], MB_ICONWARNING);
    parseVersionNotice(info['version notice']);
  finally
    info.free
  end;
  promptForUpdating(updateURL);
end;

procedure Tmainfrm.setEasyMode(easy: boolean = TRUE);
const
  LAB: array [boolean] of string = ('Expert mode', 'Easy mode');
  ico: array [boolean] of integer = (ICON_EXPERT, ICON_EASY);
begin
  easyMode := easy;
  switchMode.Caption := 'Switch to ' + LAB[not easyMode];
  // switchMode.imageIndex:=ICO[not easyMode];  disabled because it's ugly, it uses the same icon as the next menu item (accounts)
  modeBtn.Caption := 'You are in ' + LAB[easyMode];
  modeBtn.Imageindex := ico[easyMode];
  if not easyMode or graphInEasyMode then
    showGraph()
  else
    hideGraph();
  optionsFrm.mimePage.TabVisible := not easyMode;
  optionsFrm.accountsPage.TabVisible := not easyMode;
  optionsFrm.a2nPage.TabVisible := not easyMode;
  logBoxChange(NIL);
  updateSbar();
end; // switchEasyMode

procedure Tmainfrm.Rename1Click(Sender: Tobject);
begin
  if assigned(selectedFile) then
    filesbox.Selected.editText()
end;

procedure Tmainfrm.noDownloadtimeout1Click(Sender: Tobject);
const
  msg = 'Enter the number of MINUTES with no download after which the program automatically shuts down.'
    + #13'Leave blank to get no timeout.';
var
  s: string;
begin
  if noDownloadTimeout > 0 then
    s := intToStr(noDownloadTimeout)
  else
    s := '';
  if InputQuery('No downloads timeout', msg, s) then
    try
      setNoDownloadTimeout(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

procedure Tmainfrm.initVFS();
var
  f: Tfile;
begin
  uploadPaths := NIL;
  if assigned(rootNode) then
    rootNode.Delete();
  f := Tfile.createVirtualFolder('/');
  f.flags := f.flags + [FA_ROOT, FA_ARCHIVABLE];
  f.dontCountAsDownloadMask := '*.htm;*.html;*.css';
  f.defaultFileMask := 'index.html;index.htm;default.html;default.htm';
  rootFile := f;
  addFile(f, NIL, TRUE);
  rootNode := rootFile.node;
  VFSmodified := FALSE;
  lastFileOpen := '';
end; // initVFS

procedure Tmainfrm.alwaysontopChkClick(Sender: Tobject);
begin
  updateAlwaysOnTop()
end;

procedure Tmainfrm.hideGraph();
begin
  graphSplitter.hide();
  graphBox.hide();
  graphInEasyMode := FALSE;
end; // hideGraph

procedure Tmainfrm.showGraph();
begin
  graphSplitter.show();
  graphBox.show();
  graphBox.height := graph.size;
  if easyMode then
    graphInEasyMode := TRUE;
end; // showGraph

procedure Tmainfrm.Showbandwidthgraph1Click(Sender: Tobject);
begin
  showGraph()
end;

procedure Tmainfrm.Pause1Click(Sender: Tobject);
var
  cd: TconnData;
begin
  cd := selectedConnection();
  if cd = NIL then
    exit;
  with cd.conn do
    paused := not paused;
end;

procedure Tmainfrm.MIMEtypes1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.mimePage)
end;

procedure Tmainfrm.accounts1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.accountsPage)
end;

procedure Tmainfrm.CopyURL1Click(Sender: Tobject);
var
  i: integer;
  s: string;
begin
  s := '';
  for i := 0 to filesbox.SelectionCount - 1 do
    s := s + nodeToFile(filesbox.selections[i]).fullURL() + CRLF;
  setLength(s, length(s) - 2);
  setClip(s);
end;

procedure Tmainfrm.copyURLwithPasswordMenuClick(Sender: Tobject);
var
  a: Paccount;
  user, pwd: string;
  f: Tfile;
begin
  if selectedFile = NIL then
    exit;
  user := (Sender as TMenuItem).Caption;
  Delete(user, pos('&', user), 1);
  // protection may have been inherited
  f := selectedFile;
  while assigned(f) and (f.accounts[FA_ACCESS] = NIL) and (f.user = '') do
    f := f.parent;

  if f.user = user then
    pwd := f.pwd
  else
  begin
    a := getAccount(user);
    if assigned(a) then
      pwd := a.pwd
    else
      pwd := '';
  end;
  if encodePwdUrlChk.checked then
    pwd := totallyEncoded(pwd)
  else
    pwd := encodeURL(pwd);

  setClip(selectedFile.fullURL(encodeURL(user) + ':' + pwd))
end; // copyURLwithPasswordMenuClick

procedure Tmainfrm.copyURLwithAddressMenuclick(Sender: Tobject);
var
  s, addr: string;
  i: integer;
begin
  addr := (Sender as TMenuItem).Caption;
  Delete(addr, pos('&', addr), 1);

  s := '';
  for i := 0 to filesbox.SelectionCount - 1 do
    s := s + nodeToFile(filesbox.selections[i]).fullURL('', addr) + CRLF;
  setLength(s, length(s) - 2);

  setClip(s);
end; // copyURLwithAddressMenuClick

procedure Tmainfrm.CopyURLwithfingerprint1Click(Sender: Tobject);
var
  f: Tfile;
  s, hash: string;
  i: integer;
begin
  if selectedFile = NIL then
    exit;
  s := '';
  try
    for i := 0 to filesbox.SelectionCount - 1 do
    begin
      f := filesbox.selections[i].data;

      progFrm.show('Hashing ' + f.name, TRUE);
      progFrm.progress := i / filesbox.SelectionCount;
      application.ProcessMessages();

      hash := loadFingerprint(f.resource);
      if (hash = '') and f.isFile() then
      begin
        progFrm.push(1 / filesbox.SelectionCount);
        try
          hash := createFingerprint(f.resource);
        finally
          progFrm.pop()
        end;
        if saveNewFingerprintsChk.checked and (hash > '') then
          saveFile(f.resource + '.md5', hash);
      end;
      if progFrm.cancelRequested then
        exit;
      s := s + f.fullURL() + nonEmptyConcat('#!md5!', hash) + CRLF;
    end;
  finally
    progFrm.hide()
  end;
  setLength(s, length(s) - 2);

  urlBox.text := getTill(#13, s);
  setClip(s);
end;

procedure Tmainfrm.urlBoxChange(Sender: Tobject);
begin
  updateCopyBtn()
end;

procedure Tmainfrm.traymessage1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.trayPage)
end;

procedure Tmainfrm.Guide1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/hfs/guide/')
end;

procedure Tmainfrm.saveVFS(fn: string = '');
begin
  if blockLoadSave() then
    exit;
  if fn = '' then
  begin
    fn := lastFileOpen;
    if not PromptForFileName(fn, 'VirtualFileSystem|*.vfs', 'vfs', 'Save VFS',
      '', TRUE) then
      exit;
  end;
  lastFileOpen := fn;
  deleteFile(fn + BAK_EXT);
  renameFile(fn, fn + BAK_EXT);
  if not saveFile(fn, addVFSheader(getVFS())) then
  begin
    deleteFile(fn);
    renameFile(fn + BAK_EXT, fn);
    msgDlg('Error saving', MB_ICONERROR);
    exit;
  end;
  if not backupSavingChk.checked then
    deleteFile(fn + BAK_EXT);
  VFSmodified := FALSE;
  loadingVFS.disableAutosave := FALSE;
  addUniqueString(fn, trustedFiles);
end; // saveVFS

procedure Tmainfrm.filesBoxAddition(Sender: Tobject; node: TtreeNode);
begin
  VFSmodified := TRUE
end;

procedure Tmainfrm.FormClose(Sender: Tobject; var action: TCloseAction);
begin
  quitting := TRUE;
  runEventScript('quit');
  timer.enabled := FALSE;
  if autosaveoptionsChk.checked then
    saveCFG();
  // we disconnectAll() before srv.free, so we can purgeConnections()
  if assigned(srv) then
    srv.disconnectAll(TRUE);
  purgeConnections();
  freeAndNIL(srv);
  freeAndNIL(tray);
  freeAndNIL(tray_ico);
end;

procedure Tmainfrm.Logfile1Click(Sender: Tobject);
const
  msg = 'This function does not save any previous information to the log file.'
    + #13'Instead, it saves all information that appears in the log box in real-time (from when you click "OK", below).'
    + #13'Specify a filename for the log.' +
    #13'If you leave the filename blank, no log file is saved.' + #13 +
    #13'Here are some symbols you can use in the filename to split the log:' +
    #13'  %d% -- day of the month (1..31)' + #13'  %m% -- month (1..12)' +
    #13'  %y% -- year (2000..)' + #13'  %dow% -- day of the week (0..6)' +
    #13'  %w% -- week of the year (1..53)' +
    #13'  %user% -- username surrounded by parenthesis';
begin
  InputQuery('Log file', msg, logFile.filename)
end;

procedure Tmainfrm.Font1Click(Sender: Tobject);
var
  dlg: TFontDialog;
begin
  dlg := TFontDialog.create(NIL);
  dlg.Font.name := logFontName;
  dlg.Font.size := logFontSize;
  if dlg.Execute then
  begin
    logbox.Font.Assign(dlg.Font);
    logFontName := dlg.Font.name;
    logFontSize := dlg.Font.size;
  end;
  dlg.free;
end;

procedure Tmainfrm.setURL1click(Sender: Tobject);
const
  msg = 'Please insert an URL for the link' + #13 +
    #13'Do not forget to specify http:// or whatever.' +
    #13'%%ip%% will be translated to your address';
var
  i: integer;
  s: string;
begin
  if selectedFile = NIL then
    exit;
  s := selectedFile.resource;
  // this is a little help for who's linking an email. We don't mess with http/ftp because even www.asd.com may be the name of a folder.
  if ansiContainsStr(s, '@') and not ansiStartsText('mailto:', s) and
    not ansiContainsStr(s, '://') and not ansiContainsStr(s, '/') then
    s := 'mailto:' + s;
  if not InputQuery('Set URL', msg, s) then
    exit;
  for i := 0 to filesbox.SelectionCount - 1 do
    with nodeToFile(filesbox.selections[i]) do
      if FA_LINK in flags then
        resource := s;
  VFSmodified := TRUE;
end;

procedure Tmainfrm.Resetuserpass1Click(Sender: Tobject);
var
  i: integer;
  f: Tfile;
begin
  for i := 0 to filesbox.SelectionCount - 1 do
  begin
    f := filesbox.selections[i].data;
    usersInVFS.Drop(f.user, f.pwd);
    f.user := '';
    f.pwd := '';
  end;
  VFSmodified := TRUE;
  filesbox.Repaint();
end;

procedure Tmainfrm.Switchtovirtual1Click(Sender: Tobject);
var
  f: Tfile;
  under: TtreeNode;
  i: integer;
  bakIcon: integer;
  someLocked: boolean;
  nodes: TtreeNodeDynArray;
begin
  if selectedFile = NIL then
    exit;
  nodes := copySelection();

  addingItemsCounter := 0;
  try
    someLocked := FALSE;
    for i := 0 to length(nodes) - 1 do
      if assigned(nodes[i]) then
        with nodeToFile(nodes[i]) do
          if isRealFolder() and not isRoot() then
            if isLocked() then
              someLocked := TRUE
            else
            begin
              bakIcon := icon;
              f := Tfile.create(resource);
              under := node.parent;
              include(f.flags, FA_VIRTUAL);
              setNilChildrenFrom(nodes, i);
              node.Delete();
              addFile(f, under, TRUE);
              f.setupImage(bakIcon);
              f.node.focused := TRUE;
            end;
    VFSmodified := TRUE;
    if someLocked then
      msgDlg(MSG_SOME_LOCKED, MB_ICONWARNING);
  finally
    addingItemsCounter := -1
  end;
end;

procedure Tmainfrm.FormCloseQuery(Sender: Tobject; var CanClose: boolean);
begin
  queryingClose := TRUE;
  try
    if confirmexitChk.checked and not windowsShuttingDown and not quitASAP then
      if msgDlg('Quit?', MB_ICONQUESTION + MB_YESNO) = IDNO then
      begin
        CanClose := FALSE;
        exit;
      end;
    if not checkVfsOnQuit() then
    begin
      CanClose := FALSE;
      exit;
    end;
    stopAddingItems := TRUE;
    if lockTimerevent or not applicationFullyInitialized then
    begin
      quitASAP := TRUE;
      CanClose := FALSE;
    end;
    { it's better to switch off this flag, because some software that has been queried after us may prevent
      { Windows from shutting down, but the flag would stay set, while Windows is no more shutting down. }
    windowsShuttingDown := FALSE;
  finally
    queryingClose := FALSE
  end;
end;

procedure Tmainfrm.Loginrealm1Click(Sender: Tobject);
const
  msg = 'The realm string is shown on the user/pass dialog of the browser.' +
    #13'Here you can customize the realm for the login button';
begin
  if not InputQuery('Login realm', msg, loginRealm) then
    exit;
  loginRealm := trim(loginRealm);
end;

procedure Tmainfrm.Introduction1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/hfs/guide/intro.html')
end;

procedure Tmainfrm.Reset1Click(Sender: Tobject);
begin
  zeroMemory(@graph.samplesIn, SizeOf(graph.samplesIn));
  zeroMemory(@graph.samplesOut, SizeOf(graph.samplesOut));
  graph.maxV := 0;
  graph.beforeRecalcMax := 1;
  recalculateGraph();
end;

procedure Tmainfrm.Resetfileshits1Click(Sender: Tobject);
var
  n: TtreeNode;
begin
  repaintTray();
  n := rootNode;
  while assigned(n) do
  begin
    nodeToFile(n).DLcount := 0;
    n := n.getNext();
  end;
  VFSmodified := TRUE;
  autoupdatedFiles.clear();
end;

procedure Tmainfrm.persistentconnectionsChkClick(Sender: Tobject);
begin
  srv.persistentConnections := persistentconnectionsChk.checked;
  if not srv.persistentConnections then
    kickidleconnections1Click(NIL);
end;

procedure Tmainfrm.kickidleconnections1Click(Sender: Tobject);
var
  i: integer;
begin
  i := 0;
  while i < srv.conns.count do
  begin
    with conn2data(i) do
      if conn.state = HCS_IDLE then
        disconnect('kicked idle');
    inc(i);
  end;
end;

procedure Tmainfrm.Connectionsinactivitytimeout1Click(Sender: Tobject);
const
  msg = 'The connection is kicked after a timeout.' + #13'Specify in seconds.' +
    #13'Leave blank to get no timeout.';
var
  s: string;
begin
  if connectionsInactivityTimeout <= 0 then
    s := ''
  else
    s := intToStr(connectionsInactivityTimeout);
  if not InputQuery('Connection inactivity timeout', msg, s) then
    exit;
  try
    connectionsInactivityTimeout := strToUInt(s)
  except
    msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
  end;
end;

procedure Tmainfrm.splitHMoved(Sender: Tobject);
begin
  if connPnl.height > 0 then
    lastGoodConnHeight := connPnl.height
end;

procedure Tmainfrm.Clearfilesystem1Click(Sender: Tobject);
const
  msg = 'All changes will be lost'#13'Continue?';
begin
  checkIfOnlyCountersChanged();
  if VFSmodified and (msgDlg(msg, MB_ICONQUESTION + MB_YESNO) = IDNO) then
    exit;
  initVFS();
end;

function checkMultiInstance(): boolean;
begin
  result := not mono.working;
  if result then
    msgDlg(MSG_SINGLE_INSTANCE, MB_ICONERROR);
end; // checkMultiInstance

function isIntegratedInShell(): boolean;
begin
  result := (loadregistry('*\shell\Add to HFS\command', '', HKEY_CLASSES_ROOT) >
    '') and (loadregistry('Folder\shell\Add to HFS\command', '',
    HKEY_CLASSES_ROOT) > '') and (loadregistry('.vfs', '', HKEY_CLASSES_ROOT) >
    '') and (loadregistry('.vfs\shell\Open\command', '',
    HKEY_CLASSES_ROOT) > '')
end; // isIntegratedInShell

function integrateInShell(): boolean;
var
  exe: string;

  function addToContextMenuFor(kind: string): boolean;
  begin
    deleteRegistry(kind + '\shell\HFS', HKEY_CLASSES_ROOT);
    // legacy: till version 2.0 beta23 we used this key. this call is to keep the registry clean from old unused keys.
    result := saveregistry(kind + '\shell\Add to HFS\command', '',
      '"' + exe + '" "%1"', HKEY_CLASSES_ROOT);
  end;

begin
  exe := expandFileName(paramStr(0));
  result := addToContextMenuFor('*') and addToContextMenuFor('Folder') and
    saveregistry('.vfs', '', 'HFS file system', HKEY_CLASSES_ROOT) and
    saveregistry('.vfs\shell\Open\command', '', '"' + exe + '" "%1"',
    HKEY_CLASSES_ROOT)
end; // integrateInShell

procedure disintegrateShell();
begin
  deleteRegistry('*\shell\Add to HFS', HKEY_CLASSES_ROOT);
  deleteRegistry('*\shell\HFS', HKEY_CLASSES_ROOT);
  deleteRegistry('Folder\shell\Add to HFS', HKEY_CLASSES_ROOT);
  deleteRegistry('Folder\shell\HFS', HKEY_CLASSES_ROOT);
  deleteRegistry('.vfs\shell\Open\command', HKEY_CLASSES_ROOT);
  deleteRegistry('.vfs', HKEY_CLASSES_ROOT);
end; // disintegrateShell

procedure uninstall();
const
  BATCH_FILE = 'hfs.uninstall.bat';
  BATCH = 'START "" /WAIT "%s" -q' + CRLF + 'DEL "%0:s"' + CRLF +
    'DEL %%0' + CRLF;
begin
  if checkMultiInstance() then
    exit;
  mainfrm.autosaveoptionsChk.checked := FALSE;
  disintegrateShell();
  deleteCFG();
  saveFile(BATCH_FILE, format(BATCH, [paramStr(0)]));
  quitASAP := TRUE;
  execNew(BATCH_FILE);
end; // uninstall

procedure processParams_before(var params: TStringDynArray;
  allowed: string = '');
var
  i, n, consume: integer;
  fn: string;

  function getSinglePar(): string;
  begin
    if i >= length(params) - 1 then
      raise Exception.create('missing parameter needed');
    consume := 2;
    result := params[i + 1];
  end; // getSinglePar

begin
  // ** see if FindCmdLineSwitch() can be useful for the job below
  i := 2; // [0] is cwd [1] is the exe file
  while i < length(params) do
  begin
    if (length(params[i]) = 2) and (params[i][1] = '-') and
      ((allowed = '') or (pos(params[i][2], allowed) > 0)) then
    begin
      consume := 1; // number of params an option takes
      case params[i][2] of
        'q':
          quitASAP := TRUE;
        'u':
          uninstall();
        'i':
          cfgPath := includeTrailingPathDelimiter(getSinglePar());
        'b':
          userIcsBuffer := StrToIntDef(getSinglePar(), 0);
        'B':
          userSocketBuffer := StrToIntDef(getSinglePar(), 0);
        'd': // delay
          begin
            n := StrToIntDef(getSinglePar(), 0);
            if n > 0 then
              sleep(n * 100);
          end;
        'a':
          begin
            fn := getSinglePar();
            if not fileExists(fn) then
              fn := cfgPath + fn;
            if not fileExists(fn) then
              exit;
            mainfrm.setCfg(loadFile(fn));
          end;
        'c':
          mainfrm.setCfg(unescapeNL(getSinglePar()));
      end;
      for consume := 1 to consume do
        removeString(params, i);
      continue;
    end;
    inc(i);
  end;
end; // processParams_before

procedure Tmainfrm.processParams_after(var params: TStringDynArray);
var
  i: integer;
  dir: string;
begin
  dir := includeTrailingPathDelimiter(popString(params));
  popString(params); // hfs.exe
  for i := 0 to length(params) - 1 do
    if not isAbsolutePath(params[i]) then
      params[i] := dir + params[i];
  // note: 2 .vfs files will be treated as any file
  if (length(params) = 1) and isExtension(params[0], '.vfs') then
  begin
    if blockLoadSave() then
      exit;
    mainfrm.loadVFS(params[0])
  end
  else
    { parameters are also passed by other instances via sendMessage().
      { since this operation may require user interaction, it must be queued
      { because those instances wouldn't quit until the dialog is closed. }
    addArray(filesToAddQ, params);
end; // processParams_after

procedure Tmainfrm.Numberofloggeduploads1Click(Sender: Tobject);
begin
  setTrayShows('uploads')
end;

procedure Tmainfrm.compressReply(cd: TconnData);
const
  BAD_IE_THRESHOLD = 2000;
  // under this size (few bytes less, really) old IE versions will go nuts with UTF-8 pages
var
  s: string;
begin
  if not compressedbrowsingChk.checked then
    exit;
  s := cd.conn.reply.body;
  if s = '' then
    exit;
  if ipos('gzip', cd.conn.getHeader('Accept-Encoding')) = 0 then
    exit;
  // workaround for IE6 pre-SP2 bug
  if (cd.workaroundForIEutf8 = toDetect) and (cd.agent > '') then
    if reMatch(cd.agent, '^MSIE [4-6]\.', '!') > 0 then // version 6 and before
      cd.workaroundForIEutf8 := yes
    else
      cd.workaroundForIEutf8 := no;
  s := ZcompressStr2(s, zcFastest, 31, 8, zsDefault);
  if (cd.workaroundForIEutf8 = yes) and (length(s) < BAD_IE_THRESHOLD) then
    exit;
  cd.conn.addHeader('Content-Encoding: gzip');
  cd.conn.reply.body := s;
end; // compressReply

procedure Tmainfrm.Flagfilesaddedrecently1Click(Sender: Tobject);
const
  msg = 'Enter the number of MINUTES files stay flagged from their addition.' +
    #13'Leave blank to disable.';
var
  s: string;
begin
  if filesStayFlaggedForMinutes <= 0 then
    s := ''
  else
    s := intToStr(filesStayFlaggedForMinutes);
  if InputQuery('Flag new files', msg, s) then
    try
      s := trim(s);
      if s = '' then
        filesStayFlaggedForMinutes := 0
      else
        filesStayFlaggedForMinutes := strToInt(s);
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

procedure Tmainfrm.Flagasnew1Click(Sender: Tobject);
var
  i: integer;
begin
  if selectedFile = NIL then
    exit;
  for i := 0 to filesbox.SelectionCount - 1 do
    nodeToFile(filesbox.selections[i]).atime := now();
  VFSmodified := TRUE;
end;

function removeFlagNew(f: Tfile; childrenDone: boolean; par, par2: integer)
  : TfileCallbackReturn;
begin
  result := [];
  VFSmodified := TRUE;
  f.atime := now() - succ(filesStayFlaggedForMinutes) / (24 * 60)
end; // removeFlagNew

procedure Tmainfrm.Resetnewflag1Click(Sender: Tobject);
var
  i: integer;
begin
  if selectedFile = NIL then
    exit;
  for i := 0 to filesbox.SelectionCount - 1 do
    nodeToFile(filesbox.selections[i]).recursiveApply(removeFlagNew);
  VFSmodified := TRUE;
end;

procedure Tmainfrm.resetOptions1Click(Sender: Tobject);
var
  keepAccounts: Taccounts;
begin
  (Sender as TMenuItem).enabled := FALSE;
  restoreCfgBtn.show();
  eventScripts.fullText := '';
  backuppedCfg := getCfg();
  keepAccounts := accounts;
  setCfg(defaultCfg);
  accounts := keepAccounts;
end;

procedure Tmainfrm.setStatusBarText(s: string; lastFor: integer);
begin
  with sbar.Panels[sbar.Panels.count - 1] do
  begin
    alignment := taLeftJustify;
    text := s;
  end;
  sbarTextTimeout := now() + lastFor / SECONDS;
end;

procedure Tmainfrm.Donate1Click(Sender: Tobject);
begin
  openURL('http://www.rejetto.com/hfs-donate')
end;

procedure Tmainfrm.Donotlogaddress1Click(Sender: Tobject);
const
  msg = 'Any event from the following IP address mask will be not logged.';
begin
  InputQuery('Do not log address', msg, dontLogAddressMask)
end;

procedure Tmainfrm.Custom1Click(Sender: Tobject);
const
  msg = 'Specify your addresses, each per line';
var
  s: string;
  a: TStringDynArray;
begin
  s := join(CRLF, customIPs);
  if not inputqueryLong('Custom IP addresses', msg, s) then
    exit;
  customIPs := split(CRLF, s);
  removeStrings('', customIPs);
  // change the address if it is not available anymore
  a := getPossibleAddresses();
  if assigned(a) and not stringExists(defaultIP, a) then
    setDefaultIP(a[0]);
end;

procedure Tmainfrm.Findexternaladdress1Click(Sender: Tobject);
const
  msg = 'Can''t find external address'#13'( %s )';
var
  service: string;
begin
  // this is a manual request, try twice
  if not getExternalAddress(externalIP, @service) and
    not getExternalAddress(externalIP, @service) then
  begin
    msgDlg(format(msg, [service]), MB_ICONERROR);
    exit;
  end;
  setDefaultIP(externalIP);
  msgDlg(externalIP);
end;

procedure Tmainfrm.sbarDblClick(Sender: Tobject);
var
  i: integer;
begin
  i := whatStatusPanel(sbar, sbar.screenToClient(mouse.cursorPos).x);
  if (i = sbarIdxs.totalIn) or (i = sbarIdxs.totalOut) then
    if msgDlg('Do you want to reset total in/out?', MB_YESNO) = IDYES then
    begin
      outTotalOfs := -srv.bytesSent;
      inTotalOfs := -srv.bytesReceived;
    end;
  if i = sbarIdxs.banStatus then
    BannedIPaddresses1Click(NIL);
  if i = sbarIdxs.customTpl then
    Edit1Click(NIL);
  if i = sbarIdxs.oos then
    Minimumdiskspace1Click(NIL);
  if i = sbarIdxs.out then
    Speedlimit1Click(NIL);
  if i = sbarIdxs.notSaved then
    Savefilesystem1Click(NIL);
end;

procedure Tmainfrm.sbarMouseDown(Sender: Tobject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
begin
  // since right click is not used for now, it will act as double click
  if Button = mbRight then
    sbarDblClick(Sender);
end;

procedure forceDynDNSupdate(url: string = '');
const
  msg = 'This option makes pointless the option "Find external address at startup", which has now been disabled for your convenience.';
begin
  dyndns.url := url;
  if url = '' then
    exit;
  // this function is called when setting any dyndns service.
  // calling it from somewhere else may make the following test unsuitable
  if mainfrm.findExtOnStartupChk.checked then
  begin
    mainfrm.findExtOnStartupChk.checked := FALSE;
    msgDlg(msg, MB_ICONINFORMATION);
    exit;
  end;
  dyndns.active := TRUE;
  dyndns.lastIP := '';
  externalIP := '';
end; // forceDynDNSupdate

procedure Tmainfrm.Custom2Click(Sender: Tobject);
const
  msg = 'Enter URL for updating.' +
    #13'%ip% will be translated to your external IP.';
var
  s: string;
begin
  s := dyndns.url;
  if InputQuery('Enter URL', msg, s) then
    if ansiStartsText('https://', s) then
      msgDlg('Sorry, HTTPS is not supported yet', MB_ICONERROR)
    else
      forceDynDNSupdate(s);
end;

procedure Tmainfrm.Defaultpointtoaddfiles1Click(Sender: Tobject);
begin
  if selectedFile = NIL then
    exit;
  addToFolder := selectedFile.url();
  msgDlg('Ok');
end;

function dynDNSinputUserPwd(): boolean;
begin
  result := InputQuery('Enter user', 'Enter user', dyndns.user) and
    (dyndns.user > '') and InputQuery('Enter password', 'Enter password',
    dyndns.pwd) and (dyndns.pwd > '');
  dyndns.user := trim(dyndns.user);
  dyndns.pwd := trim(dyndns.pwd);
end; // dynDNSinputUserPwd

function dynDNSinputHost(): boolean;
begin
  result := FALSE;
  while TRUE do
  begin
    if not InputQuery('Enter host', 'Enter domain (full form!)', dyndns.host) or
      (dyndns.host = '') then
      exit;
    dyndns.host := trim(dyndns.host);
    if pos('://', dyndns.host) > 0 then
      chop('://', dyndns.host);
    if pos('.', dyndns.host) > 0 then
    begin
      result := TRUE;
      exit;
    end;
    msgDlg('Please, enter it in the FULL form, with dots', MB_ICONERROR);
  end;
end; // dynDNSinputHost

procedure finalizeDynDNS();
begin
  addString(dyndns.host, customIPs);
  setDefaultIP(dyndns.host);
end; // finalizeDynDNS

procedure Tmainfrm.NoIPtemplate1Click(Sender: Tobject);
begin
  if not dynDNSinputUserPwd() or not dynDNSinputHost() then
    exit;
  forceDynDNSupdate('http://' + dyndns.user + ':' + dyndns.pwd +
    '@dynupdate.no-ip.com/nic/update?hostname=' + dyndns.host);
  finalizeDynDNS();
end;

procedure Tmainfrm.CJBtemplate1Click(Sender: Tobject);
begin
  if not dynDNSinputUserPwd() then
    exit;
  forceDynDNSupdate('http://www.cjb.net/cgi-bin/dynip.cgi?username=' +
    dyndns.user + '&password=' + dyndns.pwd + '&ip=%ip%');
  dyndns.host := dyndns.user + '.cjb.net';
  finalizeDynDNS();
end;

procedure Tmainfrm.DynDNStemplate1Click(Sender: Tobject);
begin
  if not dynDNSinputUserPwd() or not dynDNSinputHost() then
    exit;
  forceDynDNSupdate('http://' + dyndns.user + ':' + dyndns.pwd +
    '@members.dyndns.org/nic/update?hostname=' + dyndns.host +
    '&myip=%ip%&wildcard=NOCHG&backmx=NOCHG&mx=NOCHG&system=dyndns');
  finalizeDynDNS();
end;

procedure Tmainfrm.Minimumdiskspace1Click(Sender: Tobject);
const
  msg = 'The upload will fail if your disk has less than the specified amount of free MegaBytes.';
var
  s: string;
begin
  if minDiskSpace <= 0 then
    s := ''
  else
    s := intToStr(minDiskSpace);
  if InputQuery('Min disk space', msg, s) then
    try
      s := trim(s);
      if s = '' then
        minDiskSpace := 0
      else
        minDiskSpace := strToInt(s);
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
end;

function pointToCharPoint(re: TRichEdit; pt: Tpoint): Tpoint;
const
  EM_EXLINEFROMCHAR = WM_USER + 54;
begin
  result.x := re.perform(EM_CHARFROMPOS, 0, integer(@pt));
  if result.x < 0 then
    exit;
  result.y := re.perform(EM_EXLINEFROMCHAR, 0, result.x);
  dec(result.x, re.perform(EM_LINEINDEX, result.y, 0));
end; // pointToCharPoint

function Tmainfrm.ipPointedInLog(): string;
var
  i: integer;
  s: string;
  pt: Tpoint;
begin
  result := '';
  pt := pointToCharPoint(logbox, logRightClick);
  if pt.x < 0 then
    pt := logbox.caretpos;
  if pt.y >= logbox.lines.count then
    exit;
  s := logbox.lines[pt.y];
  if pt.x > length(s) then
    exit;
  i := pt.x;
  while (i > 1) and (s[i] <> ' ') do
    dec(i);
  inc(i);
  s := copy(s, i, posEx(' ', s, i));
  s := trim(getTill(':', getTill('@', s)));
  if checkAddressSyntax(s, FALSE) then
    result := s;
end; // ipPointedInLog

procedure Tmainfrm.Banthisaddress1Click(Sender: Tobject);
begin
  banAddress(ipPointedInLog());
end;

procedure Tmainfrm.Address2name1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.a2nPage)
end;

procedure Tmainfrm.Addresseseverconnected1Click(Sender: Tobject);
begin
  if modalOptionsChk.checked then
    ipsEverFrm.ShowModal()
  else
    ipsEverFrm.show()
end;

procedure Tmainfrm.Renamepartialuploads1Click(Sender: Tobject);
const
  msg = 'This string will be appended to the filename.' + #13 +
    #13'If you need more control, enter a string with %name% in it, and this symbol will be replaced by the original filename.';
begin
  InputQuery('Rename partial uploads', msg, renamePartialUploads)
end;

procedure Tmainfrm.SelfTest1Click(Sender: Tobject);
const
  MSG_BEFORE = 'Here you can test if your server does work on the Internet.' +
    #13'If you are not interested in serving files over the Internet, this is NOT for you.'
    + #13 + #13'We''ll now perform a test involving network activity.' +
    #13'In order to complete this test, you may need to allow HFS''s activity in your firewall, by clicking Allow on the warning prompt.'
    + #13 + #13'WARNING: for the duration of the test, all ban rules and limits on the number of connections won''t apply.';
  MSG_OK = 'The test is successful. The server should be working fine.';
  MSG_OK_PORT =
    'Port %s is not working, but another working port has been found and set: %s.';
  MSG_3 = 'You may be behind a router or firewall.';
  MSG_6 = 'You are behind a router.' +
    #13'Ensure it is configured to forward port %s to your computer.';
  MSG_7 = 'You may be behind a firewall.' +
    #13'Ensure nothing is blocking HFS.';

  function doTheTest(host: string; port: string = ''): string;

    function findRedirection(): boolean;
    var
      http: THttpCli;
    begin
      result := FALSE;
      http := THttpCli.create(NIL);
      try
        http.url := host;
        http.agent := HFS_HTTP_AGENT;
        try
          http.get()
        except // a redirection will result in an exception
          if (http.statusCode < 300) or (http.statusCode >= 400) then
            exit;
          result := TRUE;
          host := http.hostname;
          port := http.ctrlSocket.port;
        end;
      finally
        http.free
      end
    end;

  var
    t: Tdatetime;
    ms: integer;
    name: string;
  begin
    result := '';
    if progFrm.cancelRequested then
      exit;
    { The user may be using the "port 80 redirect" service of no-ip, or a similar one.
      { The redirection service does not support a request containing "test" as URL,
      { considering it malformed (it requires a leading slash).
      { Thus, we need to find the redirect here (client-side), and then test to see if
      { the target of the redirection is a working HFS. }
    if (port = '') and not checkAddressSyntax(host) and noPortInUrlChk.checked
    then
      name := ifThen(findRedirection(), host);
    if port = '' then
      port := srv.port;
    if name = '' then
      name := host + ':' + port;
    progFrm.show('Testing ' + name + ' ...', TRUE);
    if not srv.active and not startServer() then
      exit;
    // we many need to try this specific test more than once
    repeat
      t := now();
      try
        result := httpGet(SELF_TEST_URL + '?port=' + port + '&host=' + host +
          '&natted=' + yesno[localIPlist.indexOf(externalIP) < 0])
      except
        break
      end;
      t := now() - t;
      if (result = '') or (result[1] <> '4') or progFrm.cancelRequested then
        break;
      ms := 3100 - round(t * SECONDS * 1000);
      // we mean to never query faster than 1/3s
      if ms > 0 then
        sleep(ms);
    until progFrm.cancelRequested;
  end; // doTheTest

  function successful(s: string): boolean;
  begin
    result := (s > '') and (s[1] = '1')
  end;

var
  best: record host, res: string;
end;

procedure tryDifferentHosts();
var
  i: integer;
  tries: TStringDynArray;
  s: string;
begin
  if externalIP = '' then
  begin
    progFrm.show('Retrieving external address...');
    getExternalAddress(externalIP);
  end;
  tries := getPossibleAddresses();
  // ensure defaultIP is the first one
  insertstring(defaultIP, 0, tries);
  uniqueStrings(tries);

  best.res := '';
  for i := 0 to length(tries) - 1 do
  begin
    if isLocalIP(tries[i]) then
      continue;

    progFrm.progress := succ(i) / succ(length(tries));
    s := doTheTest(tries[i]);
    // we want a digit
    if (s = '') or not(s[1] in ['0' .. '9']) then
      continue;
    // we want a better one (lower)
    if (best.res > '') and (best.res[1] <= s[1]) then
      continue;
    // we consider this to be better, record it
    best.res := s;
    best.host := tries[i];
    if successful(s) then
      break;
  end;
end; // tryDifferentHosts

procedure tryDifferentPorts();
var
  i: integer;
  tries: TStringDynArray;
  bak: record port: string;
  active: boolean;
end;
ip, s: string;
begin
  ip := defaultIP;
  if isLocalIP(ip) then
    ip := externalIP;
  if (ip = '') or isLocalIP(ip) then
    exit;
  // build list of ports we'll test
  tries := toSA(['80', '8123']);
  removeString(srv.port, tries); // already tested

  bak.active := srv.active;
  bak.port := port;
  for i := 0 to length(tries) - 1 do
  begin
    progFrm.progress := succ(i) / succ(length(tries));
    port := tries[i];
    stopServer();
    if not startServer() then
      continue;
    s := doTheTest(ip);
    if successful(s) then
      break;
  end;
  if successful(s) and (best.res = '') then
  begin
    best.res := s;
    best.host := defaultIP;
  end
  else
  begin
    port := bak.port;
    stopServer();
    if bak.active then
      startServer();
  end;
end; // tryDifferentPorts

var
  originalPort, s: string;
begin
  if msgDlg(MSG_BEFORE, MB_ICONWARNING + MB_OKCANCEL) <> IDOK then
    exit;

  originalPort := port;

  if not srv.active and not startServer() then
  begin
    port := '';
    if not startServer() then
    begin
      msgDlg('Unable to switch the server on', MB_ICONERROR);
      exit;
    end;
  end;

  if listenOn = '127.0.0.1' then
  begin
    msgDlg('Self test cannot be performed because HFS was configured to accept connections only on 127.0.0.1',
      MB_ICONERROR);
    exit;
  end;

  if httpsUrlsChk.checked then
    msgDlg('Self test doesn''t support HTTPS.'#13'It''s likely it won''t work.',
      MB_ICONWARNING);

  disableUserInteraction();
  progFrm.show('Self testing...');
  selftesting := TRUE;
  try
    best.res := '';
    progFrm.push(0.5);
    tryDifferentHosts();
    progFrm.pop();

    progFrm.push(0.4);
    if not successful(best.res) then
      tryDifferentPorts();
    progFrm.pop();

    s := best.res;
    if successful(s) then
    begin
      progFrm.progress := 1;
      if (originalPort = '') or (originalPort = port) then
        msgDlg(MSG_OK)
      else
        msgDlg(format(MSG_OK_PORT, [originalPort, port]));
      if best.host <> defaultIP then
        setDefaultIP(best.host);
      exit;
    end
    else

      if progFrm.cancelRequested then
    begin
      msgDlg('Test cancelled');
      exit;
    end;

    // error
    if s = '' then
      try
        progFrm.show('Testing internet connection...');
        httpGet(ALWAYS_ON_WEB_SERVER);
        s := 'Sorry, the test is unavailable at the moment';
      except
        s := 'Your internet connection does not work'
      end
    else
    begin
      case s[1] of
        '3':
          s := MSG_3;
        '6':
          s := format(MSG_6, [first(port, '80')]);
        '7':
          s := MSG_7;
      end;
      s := 'The test failed: server does not answer.'#13#13 + s;
    end;
    msgDlg(s, MB_ICONERROR);

  finally
    selftesting := FALSE;
    reenableUserInteraction();
    progFrm.hide();
  end;
end;

procedure Tmainfrm.Opendirectlyinbrowser1Click(Sender: Tobject);
const
  msg = '"Suggest" the browser to open directly the specified files.' +
    #13'Other files should pop up a save dialog.';
begin
  InputQuery('Open directly in browser', msg, openInBrowser)
end;

procedure Tmainfrm.noPortInUrlChkClick(Sender: Tobject);
const
  msg = 'You should not use this option unless you really know its meaning.' +
    #13'Continue?';
begin
  if noPortInUrlChk.checked and (msgDlg(msg, MB_YESNO) = ID_YES) then
    mainfrm.updateUrlBox()
  else
    noPortInUrlChk.checked := FALSE;
end;

function getTplEditor(): string;
begin
  result := first([if_(fileExists(tplEditor), nonEmptyConcat('"', tplEditor,
    '"')), loadregistry
    ('SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe', '',
    HKEY_LOCAL_MACHINE), 'notepad.exe'])
end;

procedure Tmainfrm.Edit1Click(Sender: Tobject);
begin
  if not fileExists(tplFilename) then
  begin
    tplFilename := TPL_FILE;
    saveFile(tplFilename, defaultTpl);
  end;
  exec(getTplEditor(), '"' + tplFilename + '"');
end;

procedure Tmainfrm.Editeventscripts1Click(Sender: Tobject);
const
  HELP = 'For help on how to use this file please refer http://www.rejetto.com/wiki/?title=HFS:_Event_scripts';
var
  fn: string;
begin
  fn := cfgPath + EVENTSCRIPTS_FILE;
  if not fileExists(fn) then
    saveFile(fn, HELP);
  exec(getTplEditor(), '"' + fn + '"');
end;

procedure Tmainfrm.Editresource1Click(Sender: Tobject);
const
  Caption = 'Edit resource';
var
  oldRes, oldName, res: string;
  done, nameSync: boolean;
begin
  if (selectedFile = NIL) or (FA_VIRTUAL in selectedFile.flags) then
    exit;
  res := selectedFile.resource;
  oldRes := res;
  oldName := selectedFile.name;
  // name sync, only if the name was not customized
  nameSync := selectedFile.name = extractFileName(selectedFile.resource);
  if selectedFile.isFolder then
    done := selectFolder(Caption, res)
  else
    done := PromptForFileName(res, '', '', Caption);
  if done then
    VFSmodified := TRUE;
  selectedFile.setResource(res);
  if not nameSync then
    selectedFile.setName(oldName);
  selectedFile.setupImage();
end;

procedure Tmainfrm.enableMacrosChkClick(Sender: Tobject);
const
  msg = 'The current template is using macros.' +
    #13'Do you want to cancel this action?';
begin
  if anyMacroMarkerIn(Template.fullText) and not enableMacrosChk.checked then
    enableMacrosChk.checked := msgDlg(msg, MB_ICONWARNING + MB_YESNO) = MRYES;
end;

procedure Tmainfrm.modeBtnClick(Sender: Tobject);
begin
  setEasyMode(not easyMode)
end;

procedure Tmainfrm.Shellcontextmenu1Click(Sender: Tobject);
begin
  if isIntegratedInShell() then
    disintegrateShell()
  else if integrateInShell() then
    msgDlg(MSG_ADD_TO_HFS)
  else
    msgDlg(MSG_ERROR_REGISTRY, MB_ICONERROR);
end;

procedure Tmainfrm.menuBtnClick(Sender: Tobject);
begin
  popupMainMenu()
end;

procedure Tmainfrm.menuPopup(Sender: Tobject);

  procedure showSetting(mi: TMenuItem; v: integer; unit_: string); overload;
  begin
    mi.Caption := getTill('...', mi.Caption, TRUE) +
      if_(v > 0, format('       (%d %s)', [v, unit_]))
  end;

var
  i: integer;
begin
  if quitting then
    exit; // here we access some objects like srv that may not be ready anymore

  refreshIPlist();
  for i := 1 to Fingerprints1.count - 1 do
    Fingerprints1.items[i].enabled := fingerprintsChk.checked;

  logmenu.items.Caption := 'Log';
  if menu.items.find(logmenu.items.Caption) = NIL then
    menu.items.Insert(7, logmenu.items);

  SwitchON1.Imageindex := if_(srv.active, 11, 4);
  SwitchON1.Caption := 'Switch ' + if_(srv.active, 'OFF', 'ON');

  appendmacroslog1.enabled := macrosLogChk.checked;
  stopSpidersChk.enabled := not fileExistsByURL('/robots.txt');
  Showbandwidthgraph1.visible := not graphBox.visible;
  Shellcontextmenu1.Caption := if_(isIntegratedInShell(),
    'Remove from shell context menu', 'Integrate in shell context menu');
  showSetting(mainfrm.Connectionsinactivitytimeout1,
    connectionsInactivityTimeout, 'seconds');
  showSetting(mainfrm.Minimumdiskspace1, minDiskSpace, 'MB');
  showSetting(mainfrm.Flagfilesaddedrecently1, filesStayFlaggedForMinutes,
    'minutes');
  Restore1.visible := trayed;
  Restoredefault1.enabled := tplIsCustomized;
  Numberofcurrentconnections1.checked := trayShows = 'connections';
  Numberofloggedhits1.checked := trayShows = 'hits';
  Numberofloggeddownloads1.checked := trayShows = 'downloads';
  Numberofloggeduploads1.checked := trayShows = 'uploads';
  NumberofdifferentIPaddresses1.checked := trayShows = 'ips';
  NumberofdifferentIPaddresseseverconnected1.checked := trayShows = 'ips-ever';
  ondownloadChk.checked := flashOn = 'download';
  onconnectionChk.checked := flashOn = 'connection';
  never1.checked := flashOn = '';
  defaultToVirtualChk.checked := addFolderDefault = 'virtual';
  defaultToRealChk.checked := addFolderDefault = 'real';
  askFolderKindChk.checked := addFolderDefault = '';
  name1.checked := TRUE;
  time1.checked := defSorting = 'time';
  size1.checked := defSorting = 'size';
  hits1.checked := defSorting = 'hits';
  Extension1.checked := defSorting = 'ext';
  Renamepartialuploads1.enabled := not deletePartialUploadsChk.checked;
  Seelastserverresponse1.visible := dyndns.lastResult > '';
  Disable1.visible := dyndns.url > '';
  try
    RunHFSwhenWindowsstarts1.checked := paramStr(0)
      = readShellLink(startupFilename)
  except
    RunHFSwhenWindowsstarts1.checked := FALSE
  end;
  // point out where the options will automatically be saved
  tofile1.default := saveMode = SM_FILE;
  toregistrycurrentuser1.default := saveMode = SM_USER;
  toregistryallusers1.default := saveMode = SM_SYSTEM;

  Reverttopreviousversion1.visible := fileExists(exePath + PREVIOUS_VERSION);
  Saveoptions1.visible := not easyMode;
  testerUpdatesChk.visible := not easyMode;
  preventStandbyChk.visible := not easyMode;
  searchbetteripChk.visible := not easyMode;
  Addfiles2.visible := easyMode;
  Addfolder2.visible := easyMode;
  freeLoginChk.visible := not easyMode;
  Speedlimitforsingleaddress1.visible := not easyMode;
  quitWithoutAskingToSaveChk.visible := not easyMode;
  backupSavingChk.visible := not easyMode;
  Defaultsorting1.visible := not easyMode;
  sendHFSidentifierChk.visible := not easyMode;
  URLencoding1.visible := not easyMode;
  persistentconnectionsChk.visible := not easyMode;
  DMbrowserTplChk.visible := not easyMode;
  MIMEtypes1.visible := not easyMode;
  compressedbrowsingChk.visible := not easyMode;
  modalOptionsChk.visible := not easyMode;
  Allowedreferer1.visible := not easyMode;
  Fingerprints1.visible := not easyMode;
  findExtOnStartupChk.visible := not easyMode;
  listfileswithsystemattributeChk.visible := not easyMode;
  Custom1.visible := not easyMode;
  noPortInUrlChk.visible := not easyMode;
  DynamicDNSupdater1.visible := not easyMode;
  only1instanceChk.visible := not easyMode;
  Flashtaskbutton1.visible := not easyMode;
  HintsfornewcomersChk.visible := not easyMode;
  Graphrefreshrate1.visible := not easyMode;
  foldersbeforeChk.visible := not easyMode;
  listfileswithHiddenAttributeChk.visible := not easyMode;
  saveTotalsChk.visible := not easyMode;
  trayfordownloadChk.visible := not easyMode;
  Accounts1.visible := not easyMode;
  VirtualFileSystem1.visible := not easyMode;
  Pausestreaming1.visible := not easyMode;
  maxConnections1.visible := not easyMode;
  MaxconnectionsfromSingleaddress1.visible := not easyMode;
  maxIPsDLing1.visible := not easyMode;
  maxIPs1.visible := not easyMode;
  maxDLsIP1.visible := not easyMode;
  Connectionsinactivitytimeout1.visible := not easyMode;
  Minimumdiskspace1.visible := not easyMode;
  HTMLtemplate1.visible := not easyMode;
  Shellcontextmenu1.visible := not easyMode;
  useCommentAsRealmChk.visible := not easyMode;
  openDirectlyInBrowser1.visible := not easyMode;
  keepBakUpdatingChk.visible := not easyMode;
  loginRealm1.visible := not easyMode;
  dumprequestsChk.visible := not easyMode;
  logBytesreceivedChk.visible := not easyMode;
  logBytessentChk.visible := not easyMode;
  logconnectionsChk.visible := not easyMode;
  logDisconnectionsChk.visible := not easyMode;
  autoCommentChk.visible := not easyMode;
  traymessage1.visible := not easyMode;
  showmaintrayiconChk.visible := not easyMode;
  Numberofloggedhits1.visible := not easyMode;
  Showcustomizedoptions1.visible := not easyMode;
  enableNoDefaultChk.visible := not easyMode;
  browseUsingLocalhostChk.visible := not easyMode;
  useISOdateChk.visible := not easyMode;
  Addicons1.visible := not easyMode;
  Acceptconnectionson1.visible := not easyMode;
  numberFilesOnUploadChk.visible := not easyMode;
  Renamepartialuploads1.visible := not easyMode;
  deletePartialUploadsChk.visible := not easyMode;
  updateAutomaticallyChk.visible := not easyMode;
  stopSpidersChk.visible := not easyMode;
  linksBeforeChk.visible := not easyMode;
  Debug1.visible := not easyMode;
  delayUpdateChk.visible := not easyMode;
end;

function paramsAsArray(): TStringDynArray;
var
  i: integer;
begin
  i := paramCount();
  setLength(result, i + 2);
  result[0] := Rejetto.mono.initialPath;
  for i := 0 to i do
    result[i + 1] := paramStr(i);
end; // paramsAsArray

function Tmainfrm.finalInit(): boolean;

  function getBrowserPath(): string;
  var
    i: integer;
  begin
    result := loadregistry('HTTP\shell\open\command', '', HKEY_CLASSES_ROOT);
    if result = '' then
      exit;
    i := nonQuotedPos(' ', result);
    if i > 0 then
      Delete(result, i, MAXINT);
    result := dequote(result);
  end; // getBrowserPath

  procedure fixAddToHFS();
  var
    should: string;

    procedure fix(kind: string);
    var
      s: string;
    begin
      s := loadregistry(kind + '\shell\Add to HFS\command', '',
        HKEY_CLASSES_ROOT);
      if (s > '') and (s <> should) then
        saveregistry(kind + '\shell\Add to HFS\command', '', should,
          HKEY_CLASSES_ROOT);
    end;

  begin
    should := '"' + expandFileName(paramStr(0)) + '" "%1"';
    fix('*');
    fix('Folder');
  end; // fixAddToHFS

  function loadAndApplycfg(): boolean;
  const
    msg = 'You are invited to re-insert your No-IP configuration, otherwise the updater won''t work as expected.';
  var
    iniS, tplS: string;
  begin
    loadCfg(iniS, tplS);
    result := setCfg(iniS, FALSE);
    // convert old no-ip template url to new one (build#204)
    if dyndns.active and ansiContainsText(dyndns.url, 'no-ip.com') and
      not ansiContainsText(dyndns.url, 'nic/update') and
      (msgDlg(msg, MB_OKCANCEL + MB_ICONWARNING) = MROK) then
      NoIPtemplate1Click(NIL);
    if (tplS > '') and assigned(Template) then
      setTplText(tplS);
    if lastUpdateCheck = 0 then
      lastUpdateCheck := getMtime(lastUpdateCheckFN);
  end; // loadAndApplycfg

  procedure strToConnColumns(l: string);
  var
    s, labl: string;
    i: integer;
  begin
    while l > '' do
      with connBox.columns do
      begin
        s := chop('|', l);
        if s = '' then
          continue;
        labl := chop(';', s);
        for i := 0 to count - 1 do
          with items[i] do
            if Caption = labl then
            begin
              Width := StrToIntDef(s, Width);
              break;
            end;
      end;
  end; // strToConnColumns

var
  cfgLoaded: boolean;
  params: TStringDynArray;
begin
  result := FALSE;

  { it would be nice, but this is screwing our layouts. so for now we'll just stay with the main window.
    for i:=0 to application.componentCount-1 do
    if application.components[i] is Tform then
    fixFontFor(application.components[i] as Tform);
  }
  fixFontFor(mainfrm);
  sbar.Canvas.Font.Assign(sbar.Font);
  // this is just a workaround, i don't exactly understand the need of it.

  // some windows versions do not support multiline tray tips
  if winVersion < WV_2000 then
    trayNL := '  ';

  trayMsg := '%ip%' + trayNL + 'Uptime: %uptime%' + trayNL +
    'Downloads: %downloads%';

  startingImagesCount := mainfrm.images.count;
  srv := ThttpSrv.create();
  srv.autoFreeDisconnectedClients := FALSE;
  srv.limiters.add(globalLimiter);
  srv.onEvent := httpEvent;
  tray_ico := Ticon.create();
  tray := TmyTrayIcon.create(self);
  DragAcceptFiles(Handle, TRUE);
  Caption := format('HFS ~ HTTP File Server %s%sBuild %s',
    [HFS.Consts.VERSION, stringOfChar(' ', 80), VERSION_BUILD]);
  application.Title := format('HFS %s (%s)', [HFS.Consts.VERSION, VERSION_BUILD]);
  setSpeedLimit(-1);
  setSpeedLimitIP(-1);
  setGraphRate(10);
  setMaxConnections(0);
  setMaxConnectionsIP(0);
  setMaxDLs(0);
  setMaxDLsIP(0);
  setMaxIPs(0);
  setMaxIPsDLing(0);
  setNoDownloadTimeout(0);
  setAutosave(autosaveVFS, 0);
  setAutoFingerprint(0);
  setLogToolbar(FALSE);

  autosaveVFS.minimum := 5;
  autosaveVFS.menu := autosaveevery1;

  params := paramsAsArray();
  processParams_before(params, 'i');

  initVFS();
  setFilesBoxExtras(winVersion <> WV_VISTA);

  defaultCfg := xtpl(getCfg(), ['active=no', 'active=yes']);

  loadEvents();
  cfgLoaded := FALSE;
  // if SHIFT is pressed skip configuration loading
  if not holdingKey(VK_SHIFT) then
    cfgLoaded := loadAndApplycfg()
  else
    setStatusBarText('Clean start');

  // CTRL avoids the only1instance setting
  if not holdingKey(VK_CONTROL) and only1instanceChk.checked and not mono.master
  then
  begin
    result := FALSE;
    quitASAP := TRUE;
  end;

  if not cfgLoaded then
    setTplText(defaultTpl);

  processParams_before(params);

  if not quitASAP then
  begin

    if not cfgLoaded then
    begin
      startServer();
      if not isIntegratedInShell() then
        with TshellExtFrm.create(mainfrm) do
          try
            if ShowModal() = MRYES then
              if not integrateInShell() then
                msgDlg(MSG_ERROR_REGISTRY, MB_ICONERROR);
          finally
            free
          end;
    end;

    if findExtOnStartupChk.checked and getExternalAddress(externalIP) then
      setDefaultIP(externalIP);

  end;

  // no address set or not available anymore
  if not stringExists(defaultIP, getPossibleAddresses()) then
    setDefaultIP(getIP());

  progFrm := TprogressForm.create();
  progFrm.preventBackward := TRUE;
  updateUrlBox();
  application.HintPause := 100;
  splitV.AutoSnap := FALSE;
  splitV.AutoSnap := TRUE;
  splitV.update();
  graph.size := graphBox.height;
  if not quitASAP then
  begin
    if autocopyURLonstartChk.checked then
      setClip(rootFile.fullURL());

    if reloadonstartupChk.checked then
      if not fileExists(lastFileOpen) and not fileExists(lastFileOpen + BAK_EXT)
      then
        lastFileOpen := '';

    if getMtime(VFS_TEMP_FILE) > getMtime(lastFileOpen) then
      if msgDlg(
        'A file system backup has been created for a system shutdown.'#13'Do you want to restore this backup?',
        MB_YESNO + MB_ICONWARNING) = MRYES then
      begin
        deleteFile(lastFileOpen + BAK_EXT);
        if renameFile(lastFileOpen, lastFileOpen + BAK_EXT) then
          renameFile(VFS_TEMP_FILE, lastFileOpen)
        else
          lastFileOpen := VFS_TEMP_FILE
      end;

    loadVFS(lastFileOpen);
  end;
  processParams_after(params);

  if not quitASAP then
  begin
    if not cfgLoaded then
      setEasyMode(easyMode);
    tray.setIcon(tray_ico);
    tray.onEvent := trayEvent;
    if showmaintrayiconChk.checked then
      addTray();
  end;
  timer.enabled := TRUE;
  applicationFullyInitialized := TRUE;
  if quitASAP then
  begin
    application.showmainform := FALSE;
    Close();
    exit;
  end;

  show();
  strToConnColumns(serializedConnColumns);
  if startMinimizedChk.checked then
    application.Minimize();
  if findExtOnStartupChk.checked and (externalIP = '') then
    setStatusBarText('Search for external address failed', 30);
  updatePortBtn();
  fixAddToHFS();
  filesbox.setFocus();
  // loadEvents();
  FormResize(NIL); // recalculate to solve graphical glitches

  if not tplIsCustomized then
    runTplImport();

  runEventScript('start');
  { ** trying to move loadEvents() before loadCfg()
    if srv.active then
    runEventScript('server start'); // because this event wouldn't fire at start, the server was already on
  }
end; // finalInit

function expertModeNeededMsg(): string;
begin
  result := if_(easyMode, 'Switch to expert mode.')
end;

procedure Tmainfrm.Dontlogsomefiles1Click(Sender: Tobject);
begin
  msgDlg(expertModeNeededMsg() +
    #13'Select the files/folder you don''t want to be logged,' +
    #13'then right click and select "Don''t log".');
end;

procedure Tmainfrm.progFrmHttpGetUpdate(Sender: Tobject; buffer: pointer;
  len: integer);
begin
  with Sender as THttpCli do
  begin
    progFrm.progress := safeDiv(0.0 + RcvdCount, contentLength);
    if progFrm.cancelRequested then
      abort();
  end;
end; // progFrmHttpGetUpdate

function purgeFilesCB(f: Tfile; childrenDone: boolean; par, par2: integer)
  : TfileCallbackReturn;
begin
  result := [];
  if f.locked or f.isRoot() then
    exit;
  result := [FCB_RECALL_AFTER_CHILDREN];
  if f.isFile() and purgeFrm.rmFilesChk.checked and not fileExists(f.resource)
    or f.isRealFolder() and purgeFrm.rmRealFoldersChk.checked and
    not System.SysUtils.DirectoryExists(f.resource) or f.isVirtualFolder() and
    purgeFrm.rmEmptyFoldersChk.checked and (f.node.count = 0) then
    result := [FCB_DELETE]; // don't dig further
end; // purgeFilesCB

procedure Tmainfrm.Properties1Click(Sender: Tobject);
begin
  if selectedFile = NIL then
    exit;

  filepropFrm := TfilepropFrm.create(mainfrm);
  try
    if filepropFrm.ShowModal() = mrCancel then
      exit;
  finally
    freeAndNIL(filepropFrm)
  end;
  VFSmodified := TRUE;
  filesbox.invalidate();
end;

procedure Tmainfrm.Purge1Click(Sender: Tobject);
var
  f: Tfile;
begin
  f := selectedFile;
  if f = NIL then
    f := rootFile;
  if purgeFrm = NIL then
    application.CreateForm(TpurgeFrm, purgeFrm);
  if purgeFrm.ShowModal() <> MROK then
    exit;
  f.recursiveApply(purgeFilesCB);
end;

procedure Tmainfrm.UninstallHFS1Click(Sender: Tobject);
begin
  if checkMultiInstance() then
    exit;
  if msgDlg('Delete HFS and all settings?', MB_ICONQUESTION + MB_YESNO) <> IDYES
  then
    exit;
  uninstall();
end;

procedure Tmainfrm.maxIPs1Click(Sender: Tobject);
const
  msg = 'Max simultaneous addresses.'#13 + MSG_EMPTY_NO_LIMIT;
  MSG2 = 'In this moment there are %d different addresses';
var
  s: string;
  i: integer;
begin
  if maxIPs > 0 then
    s := intToStr(maxIPs)
  else
    s := '';
  if InputQuery('Max addresses', msg, s) then
    try
      setMaxIPs(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if maxIPs = 0 then
    exit;
  i := countIPs();
  if i > maxIPs then
    msgDlg(format(MSG2, [i]), MB_ICONWARNING);
end;

procedure Tmainfrm.maxIPsDLing1Click(Sender: Tobject);
const
  msg = 'Max simultaneous addresses downloading.'#13 + MSG_EMPTY_NO_LIMIT;
  MSG2 = 'In this moment there are %d different addresses downloading';
var
  s: string;
  i: integer;
begin
  if maxIPsDLing > 0 then
    s := intToStr(maxIPsDLing)
  else
    s := '';
  if InputQuery('Max addresses downloading', msg, s) then
    try
      setMaxIPsDLing(strToUInt(s))
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  if maxIPsDLing = 0 then
    exit;
  i := countIPs(TRUE);
  if i > maxIPsDLing then
    msgDlg(format(MSG2, [i]), MB_ICONWARNING);
end;

procedure Tmainfrm.Maxlinesonscreen1Click(Sender: Tobject);
const
  msg = 'Max lines on screen';
var
  s: string;
begin
  s := if_(logMaxLines > 0, intToStr(logMaxLines));
  repeat
    if not InputQuery(msg, msg + '.'#13 + MSG_EMPTY_NO_LIMIT, s) then
      break;
    try
      logMaxLines := strToUInt(s);
      break;
    except
      msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
    end;
  until FALSE;
end;

procedure Tmainfrm.Autosaveevery1Click(Sender: Tobject);
begin
  autosaveClick(autosaveVFS, 'file system')
end;

procedure Tmainfrm.Apachelogfileformat1Click(Sender: Tobject);
const
  msg = 'Here you can specify how to format the log file complying Apache standard.'
    + #13'Leave blank to get bare copy of screen on file.' + #13 + #13'Example:'
    + #13'   %h %l %u %t "%r" %>s %b';
begin
  InputQuery('Apache log file format', msg, logFile.apacheFormat)
end;

procedure Tmainfrm.Bindroottorealfolder1Click(Sender: Tobject);
var
  f: Tfile;
  res: string;
begin
  f := selectedFile;
  if (f = NIL) or not f.isVirtualFolder() or not f.isRoot() then
    exit;
  res := exePath;
  if not selectFolder('', res) then
    exit;
  f.setResource(res);
  exclude(f.flags, FA_VIRTUAL);
  VFSmodified := TRUE;
end;

procedure Tmainfrm.Unbindroot1Click(Sender: Tobject);
var
  f: Tfile;
begin
  f := selectedFile;
  if (f = NIL) or not f.isRealFolder() or not f.isRoot() then
    exit;
  f.setResource('');
  f.uploadFilterMask := '';
  f.accounts[FA_UPLOAD] := NIL;
  include(f.flags, FA_VIRTUAL);
  VFSmodified := TRUE;
end;

procedure Tmainfrm.SwitchON1Click(Sender: Tobject);
begin
  toggleServer()
end;

procedure Tmainfrm.Switchtorealfolder1Click(Sender: Tobject);
var
  i: integer;
  someLocked: boolean;
  list: TtreeNodeDynArray;
begin
  if selectedFile = NIL then
    exit;
  someLocked := FALSE;
  list := copySelection();
  for i := 0 to length(list) - 1 do
    if assigned(list[i]) then
      with nodeToFile(list[i]) do
        if isVirtualFolder() and not isRoot() and (resource > '') then
          if isLocked() then
            someLocked := TRUE
          else
          begin
            exclude(flags, FA_VIRTUAL);
            setResource(resource);
            setupImage();
            setNilChildrenFrom(list, i);
            node.DeleteChildren();
          end;
  VFSmodified := TRUE;
  if someLocked then
    msgDlg(MSG_SOME_LOCKED, MB_ICONWARNING);
end;

procedure Tmainfrm.abortBtnClick(Sender: Tobject);
begin
  stopAddingItems := TRUE
end;

procedure Tmainfrm.Seelastserverresponse1Click(Sender: Tobject);
var
  fn: string;
begin
  if ipos('<html>', dyndns.lastResult) = 0 then
  begin
    msgDlg(dyndns.lastResult);
    exit;
  end;
  fn := saveTempFile(dyndns.lastResult);
  if fn = '' then
  begin
    msgDlg(MSG_NO_TEMP, MB_ICONERROR);
    exit;
  end;
  renameFile(fn, fn + '.html');
  exec(fn + '.html');
end;

procedure Tmainfrm.Showcustomizedoptions1Click(Sender: Tobject);
var
  default: Tstrings;
  current, defV, v, k: string;
  diff: string;
begin
  default := TstringList.create();
  default.text := defaultCfg;
  current := getCfg();
  diff := '# ' + HFS.Consts.VERSION + ' (build ' + VERSION_BUILD + ')' + CRLF;

  while current > '' do
  begin
    v := chopLine(current);
    k := chop('=', v);
    if ansiEndsStr('-width', k) or ansiEndsStr('-height', k) or
      stringExists(k, ['active', 'window', 'graph-visible', 'graph-size', 'ip',
      'accounts', 'dynamic-dns-user', 'dynamic-dns-host', 'ips-ever',
      'ips-ever-connected', 'icon-masks-user-images', 'last-external-address',
      'last-dialog-folder']) then
      continue;

    defV := default.values[k];
    if defV = v then
      continue;
    if k = 'dynamic-dns-updater' then
    begin // remove login data
      v := base64decode(v);
      chop('//', v);
      v := chop('/', v);
      if ansiContainsStr(v, '@') then
        chop('@', v);
      v := '...' + v + '...';
    end;
    diff := diff + k + '=' + v + CRLF + '# default: ' + defV + CRLF + CRLF;
  end;
  default.free;

  diffFrm.memoBox.text := diff;
  diffFrm.ShowModal();
end;

procedure Tmainfrm.useISOdateChkClick(Sender: Tobject);
begin
  applyISOdateFormat()
end;

procedure Tmainfrm.RunHFSwhenWindowsstarts1Click(Sender: Tobject);
begin
  deleteFile(startupFilename);
  // we delete both for deactivation (of course) and before activation (to purge possible existing links to other exe files)
  if not(Sender as TMenuItem).checked then
    createShellLink(startupFilename, paramStr(0));
end;

procedure Tmainfrm.Runscript1Click(Sender: Tobject);
begin
  if not fileExists(tempScriptFilename) then
    saveFile(tempScriptFilename, '');
  runScriptLast := getMtime(tempScriptFilename);
  if runScriptFrm = NIL then
    runScriptFrm := TrunScriptFrm.create(self);
  runScriptFrm.show();
  exec(getTplEditor(), '"' + tempScriptFilename + '"');
end;

procedure Tmainfrm.minimizeToTray();
begin
  application.Minimize();
  addTray();
  showWindow(application.Handle, SW_HIDE); // hide taskbar button
  trayed := TRUE;
end; // minimizeToTray

procedure Tmainfrm.askFolderKindChkClick(Sender: Tobject);
begin
  addFolderDefault := ''
end;

procedure Tmainfrm.defaultToVirtualChkClick(Sender: Tobject);
begin
  addFolderDefault := 'virtual'
end;

procedure Tmainfrm.defaultToRealChkClick(Sender: Tobject);
begin
  addFolderDefault := 'real'
end;

procedure Tmainfrm.Addicons1Click(Sender: Tobject);
var
  files: TStringDynArray;
  i, n: integer;
begin
  if not selectFiles('', files) then
    exit;
  n := images.count;
  for i := 0 to length(files) - 1 do
    getImageIndexForFile(files[i]);
  n := images.count - n;
  msgDlg(format('%d new icons added', [n]));
end;

procedure Tmainfrm.Iconmasks1Click(Sender: Tobject);
begin
  showOptions(optionsFrm.iconsPage)
end;

procedure Tmainfrm.Anyaddress1Click(Sender: Tobject);
begin
  listenOn := '';
  restartServer();
end;

procedure Tmainfrm.acceptOnMenuclick(Sender: Tobject);
begin
  listenOn := (Sender as TMenuItem).Caption;
  Delete(listenOn, pos('&', listenOn), 1);
  restartServer();
end; // acceptOnMenuclick

procedure Tmainfrm.filesBoxEndDrag(Sender, Target: Tobject; x, y: integer);
begin
  scrollFilesBox := -1;
  filesbox.refresh();
end;

procedure Tmainfrm.filesBoxEnter(Sender: Tobject);
begin
  setFilesBoxExtras(TRUE)
end;

procedure Tmainfrm.filesBoxExit(Sender: Tobject);
begin
  setFilesBoxExtras(filesbox.MouseInClient)
end;

procedure Tmainfrm.Disable1Click(Sender: Tobject);
begin
  dyndns.url := '';
  msgDlg('Dynamic DNS updater disabled');
end;

procedure Tmainfrm.saveNewFingerprintsChkClick(Sender: Tobject);
const
  msg = 'This option creates an .md5 file for every new calculated fingerprint.'
    + #13'Use with care to get not your disk invaded by these files.';
begin
  if saveNewFingerprintsChk.checked then
    msgDlg(msg, MB_ICONWARNING);
end;

procedure Tmainfrm.Createfingerprintonaddition1Click(Sender: Tobject);
const
  msg = 'When you add files and no fingerprint is found, it is calculated.' +
    #13'To avoid long waitings, set a limit to file size (in KiloBytes).' +
    #13'Leave empty to disable, and have no fingerprint created.';
var
  s: string;
begin
  if autoFingerprint = 0 then
    s := ''
  else
    s := intToStr(autoFingerprint);
  if not InputQuery('Auto fingerprint', msg, s) then
    exit;
  try
    setAutoFingerprint(strToUInt(s))
  except
    msgDlg(MSG_INVALID_VALUE, MB_ICONERROR)
  end;
end;

procedure Tmainfrm.pwdInPagesChkClick(Sender: Tobject);
const
  msg = 'This feature is INCOMPATIBLE with Internet Explorer.';
begin
  if pwdInPagesChk.checked and (msgDlg(msg, MB_ICONWARNING + MB_OKCANCEL) = IDOK)
  then
  begin
    msgDlg(MSG_ENABLED);
    exit;
  end;
  pwdInPagesChk.checked := FALSE;
  msgDlg(MSG_DISABLED)
end;

procedure Tmainfrm.Howto1Click(Sender: Tobject);
begin
  msgDlg(getRes('uploadHowTo'))
end;

procedure Tmainfrm.Name1Click(Sender: Tobject);
begin
  defSorting := 'name'
end;

procedure Tmainfrm.Size1Click(Sender: Tobject);
begin
  defSorting := 'size'
end;

procedure Tmainfrm.Time1Click(Sender: Tobject);
begin
  defSorting := 'time'
end;

procedure Tmainfrm.Hits1Click(Sender: Tobject);
begin
  defSorting := 'hits'
end;

procedure Tmainfrm.Resettotals1Click(Sender: Tobject);
begin
  resetTotals()
end;

procedure Tmainfrm.copyBtnClick(Sender: Tobject);
begin
  setClip(urlBox.text)
end;

function Tmainfrm.copySelection(): TtreeNodeDynArray;
var
  i: integer;
begin
  setLength(result, filesbox.SelectionCount);
  for i := 0 to filesbox.SelectionCount - 1 do
    result[i] := filesbox.selections[i];
end; // copySelection

procedure Tmainfrm.menuMeasure(Sender: Tobject; cnv: Tcanvas; var w: integer;
  var h: integer);
begin
  with Sender as TMenuItem do
    if isLine() then
      w := cnv.TextWidth(hint + '----')
    else
      w := cnv.TextWidth(Caption + '----') + images.Width;
  h := getSystemMetrics(SM_CYMENU);
end;

procedure Tmainfrm.menuDraw(Sender: Tobject; cnv: Tcanvas; r: Trect;
  Selected: boolean);
var
  mi: TMenuItem;
  s: string;
  i: integer;
begin
  mi := Sender as TMenuItem;
  if mi.isLine() then
  begin
    i := (r.bottom + r.top) div 2;
    cnv.pen.color := clBtnHighlight;
    cnv.MoveTo(r.left, i);
    cnv.LineTo(r.Right, i);
    cnv.pen.color := clBtnShadow;
    cnv.MoveTo(r.left, i - 1);
    cnv.LineTo(r.Right, i - 1);

    if mi.hint = '' then
      exit;
    s := ' ' + mi.hint + ' ';
    inc(r.top, cnv.textHeight(s) div 5);
    cnv.Font.color := clBtnHighlight;
    drawText(cnv.Handle, pchar(s), -1, r, DT_VCENTER or DT_CENTER);
    SetBkMode(cnv.Handle, Transparent);
    cnv.Font.color := clBtnShadow;
    dec(r.left);
    dec(r.top);
    drawText(cnv.Handle, pchar(s), -1, r, DT_VCENTER or DT_CENTER);
    exit;
  end;
  cnv.FillRect(r);
  inc(r.left, images.Width * 2);
  inc(r.top, 2);
  drawText(cnv.Handle, pchar(mi.Caption), -1, r, DT_LEFT or DT_VCENTER);
  dec(r.left, images.Width * 2);

  if mi.Imageindex >= 0 then
    images.draw(cnv, r.left + 1, r.top, mi.Imageindex);
  if mi.checked then
  begin
    cnv.Font.name := 'WingDings';
    with cnv.Font do
      size := size + 2;
    cnv.TextOut(r.left + images.Width, r.top, '�'); // check mark
  end;
end;

INITIALIZATION
  randomize();
  setErrorMode(SEM_FAILCRITICALERRORS);
  exePath := extractFilePath(expandFileName(paramStr(0)));
  cfgPath := exePath;
  // we give priority to exePath because some people often clear the temp folder
  tmpPath := exePath;
  if saveFile(tmpPath + 'test.tmp', '') then
    deleteFile(tmpPath + 'test.tmp')
  else
    tmpPath := getTempDir();
  lastUpdateCheckFN := tmpPath + 'HFS last update check.tmp';
  setCurrentDir(exePath);
  // sometimes people mess with the working directory, so we force it to the exe path
  if fileExists('default.tpl') then
    defaultTpl := loadFile('default.tpl')
  else
    defaultTpl := getRes('defaultTpl');
  tpl_help := getRes('tplHlp');
  Template := TTemplate.create();
  defSorting := 'name';
  dmBrowserTpl := TTemplate.create(getRes('dmBrowserTpl'));
  filelistTpl := TTemplate.create(getRes('filelistTpl'));
  globalLimiter := TspeedLimiter.create();
  ip2obj := THashedStringList.create();
  etags := THashedStringList.create();
  sessions := THashedStringList.create();
  ipsEverConnected := THashedStringList.create();
  ipsEverConnected.sorted := TRUE;
  ipsEverConnected.duplicates := dupIgnore;
  ipsEverConnected.delimiter := ';';
  logMaxLines := 2000;
  trayShows := 'downloads';
  flashOn := 'download';
  forwardedMask := '127.0.0.1';
  runningOnRemovable := DRIVE_REMOVABLE = GetDriveTypeA
    (pAnsiChar(exePath[1] + ':\'));
  etags.values['exe'] := strMD5(dateToHTTP(getMtimeUTC(paramStr(0))));

  dll := GetModuleHandle('kernel32.dll');
  if dll <> HINSTANCE_ERROR then
    setThreadExecutionState := getprocaddress(dll, 'SetThreadExecutionState');

  toDelete := Tlist.create();
  usersInVFS := TusersInVFS.create();

  openInBrowser:='*.htm;*.html;*.jpg;*.jpeg;*.gif;*.png;*.txt;*.swf;*.svg';
  MIMEtypes:=toSA([
    '*.htm;*.html', 'text/html',
    '*.jpg;*.jpeg;*.jpe', 'image/jpeg',
    '*.gif', 'image/gif',
    '*.png', 'image/png',
    '*.bmp', 'image/bmp',
    '*.ico', 'image/x-icon',
    '*.mpeg;*.mpg;*.mpe', 'video/mpeg',
    '*.avi', 'video/x-msvideo',
    '*.txt', 'text/plain',
    '*.css', 'text/css',
    '*.js',  'text/javascript'
  ]);

  systemimages:= getSystemimages();
  saveMode := SM_USER;
  lastDialogFolder := getCurrentDir();;
  autoupdatedFiles := TstringToIntHash.create();
  iconsCache := TiconsCache.create();
  dyndns.active := TRUE;
  connectionsInactivityTimeout := 60; // 1 minute
  startupFilename := getShellFolder('Startup') + '\HFS.lnk';
  tempScriptFilename := getTempDir() + 'hfs script.tmp';

  logFile.apacheZoneString := if_(GMToffset < 0, '-', '+') +
    format('%.2d%.2d', [abs(GMToffset div 60), abs(GMToffset mod 60)]);

FINALIZATION
  progFrm.free;
  toDelete.free;
  Template.free;
  filelistTpl.free;
  autoupdatedFiles.free;
  iconsCache.free;
  usersInVFS.free;
  globalLimiter.Free;
  ip2obj.free;
  ipsEverConnected.free;
  etags.free;

end.
