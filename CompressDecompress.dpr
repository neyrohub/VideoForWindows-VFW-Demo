program CompressDecompress;

uses
  Forms,
  uMain in 'uMain.pas' {VideoForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TVideoForm, VideoForm);
  Application.Run;
end.
