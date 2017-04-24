unit shellExtDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TshellExtFrm = class(TForm)
    Image1: TImage;
    Panel1: TPanel;
    Label1: TLabel;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  shellExtFrm: TshellExtFrm;

implementation

{$R *.dfm}

uses
  Vcl.Imaging.GIFImg,
  utilLib;

procedure TshellExtFrm.FormCreate(Sender: TObject);
var
  gif: TGIFImage;
begin
  // turbo delphi doesn't allow me to load a gif from the form designer, so i do it run-time
  gif := stringToGif(getRes('shell', 'GIF'));
  try
    Image1.picture.assign(gif);
  finally
    gif.free
  end;
end;

end.
