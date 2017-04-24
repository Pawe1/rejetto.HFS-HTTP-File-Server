unit longinputDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TlonginputFrm = class(TForm)
    bottomPnl: TPanel;
    okBtn: TButton;
    cancelBtn: TButton;
    topPnl: TPanel;
    msgLbl: TLabel;
    inputBox: TMemo;
    procedure bottomPnlResize(Sender: TObject);
    procedure inputBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.dfm}

procedure TlonginputFrm.bottomPnlResize(Sender: TObject);
begin
  okBtn.left := (bottomPnl.Width - cancelBtn.BoundsRect.right +
    okBtn.BoundsRect.left) div 2;
  cancelBtn.left := okBtn.BoundsRect.right + 10;
end;

procedure TlonginputFrm.inputBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Shift = [ssCtrl] then
    if Key = ord('A') then
      inputBox.SelectAll();
end;

end.
