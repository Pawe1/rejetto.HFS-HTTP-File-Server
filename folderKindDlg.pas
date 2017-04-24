unit folderKindDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons;

type
  TfolderKindFrm = class(TForm)
    realLbl: TLabel;
    virtuaLbl: TLabel;
    realBtn: TBitBtn;
    virtuaBtn: TBitBtn;
    Label3: TLabel;
    hintLbl: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils;

procedure TfolderKindFrm.FormCreate(Sender: TObject);
begin
  realBtn.Font.Style := [fsBold];
  with hintLbl do
    caption := ansiReplaceStr(caption, '? ', '?'#13);
end;

end.
