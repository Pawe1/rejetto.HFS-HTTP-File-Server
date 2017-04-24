unit ipsEverDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TipsEverFrm = class(TForm)
    ipsBox: TMemo;
    resetBtn: TButton;
    totalLbl: TLabel;
    editBtn: TButton;
    procedure resetBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure editBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    procedure refreshData();
    { Public declarations }
  end;

var
  ipsEverFrm: TipsEverFrm;

implementation

{$R *.dfm}

uses
  main, utilLib;

procedure TipsEverFrm.resetBtnClick(Sender: TObject);
begin
  ipsEverConnected.clear();
  refreshData();
end;

procedure TipsEverFrm.editBtnClick(Sender: TObject);
var
  fn: string;
begin
  fn := saveTempFile(ipsEverConnected.text);
  if renameFile(fn, fn + '.txt') then
    exec(fn + '.txt')
  else
    msgDlg(MSG_NO_TEMP, MB_ICONERROR);
end;

procedure TipsEverFrm.FormShow(Sender: TObject);
begin
  refreshData()
end;

procedure TipsEverFrm.refreshData();
begin
  ipsBox.text := ipsEverConnected.text;
  totalLbl.caption := format('Total: %d', [ipsEverConnected.count]);
  repaintTray();
end;

end.
