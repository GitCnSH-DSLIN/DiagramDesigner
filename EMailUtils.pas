unit EMailUtils;

interface

uses Windows, Classes, SysUtils, Forms;

{
Example usage:

procedure TForm1.Button1Click(Sender: TObject);
var
  mail: TStringList;
begin
  mail := TStringList.Create;
  try
    mail.values['to'] := 'Receiver-Email@test.xyz';
    mail.values['subject'] := 'Hello';
    mail.values['body'] := 'blah';
    mail.values['attachment0'] := 'C:\Test1.txt';
    mail.values['attachment1']:='C:\Test2.txt';
    sendEMail(Application.Handle, mail);
  finally
    mail.Free;
  end;
end;
}

function SendEMail(Handle: THandle; Mail: TStrings): Cardinal;

implementation

uses
  Mapi;

resourcestring
  rsErrorWhileTryingToSendEMail = 'Error while trying to send e-mail';

function SendEMail(Handle: THandle; Mail: TStrings): Cardinal;
type
  TAttachAccessArray = array [0..0] of TMapiFileDesc;
  PAttachAccessArray = ^TAttachAccessArray;
var
  MapiMessage: TMapiMessage;
  Receip: TMapiRecipDesc;
  Attachments: PAttachAccessArray;
  AttachCount: Integer;
  i1: integer;
  FileName: string;
  dwRet: Cardinal;
  MAPI_Session: Cardinal;
  WndList: Pointer;
begin
  dwRet := MapiLogon(Handle,
    PChar(''),
    PChar(''),
    MAPI_LOGON_UI or MAPI_NEW_SESSION,
    0, @MAPI_Session);

  if (dwRet <> SUCCESS_SUCCESS) then
    raise Exception.Create(rsErrorWhileTryingToSendEMail);
  try
    FillChar(MapiMessage, SizeOf(MapiMessage), #0);
    Attachments := nil;
    FillChar(Receip, SizeOf(Receip), #0);

    if Mail.Values['to'] <> '' then
    begin
      Receip.ulReserved := 0;
      Receip.ulRecipClass := MAPI_TO;
      Receip.lpszName := StrNew(PChar(Mail.Values['to']));
      Receip.lpszAddress := StrNew(PChar('SMTP:' + Mail.Values['to']));
      Receip.ulEIDSize := 0;
      MapiMessage.nRecipCount := 1;
      MapiMessage.lpRecips := @Receip;
    end;

    AttachCount := 0;

    for i1 := 0 to MaxInt do
    begin
      if Mail.Values['attachment' + IntToStr(i1)] = '' then
        break;
      Inc(AttachCount);
    end;

    if AttachCount > 0 then
    begin
      GetMem(Attachments, SizeOf(TMapiFileDesc) * AttachCount);

      for i1 := 0 to AttachCount - 1 do
      begin
        FileName := Mail.Values['attachment' + IntToStr(i1)];
        Attachments[i1].ulReserved := 0;
        Attachments[i1].flFlags := 0;
        Attachments[i1].nPosition := ULONG($FFFFFFFF);
        Attachments[i1].lpszPathName := StrNew(PChar(FileName));
        Attachments[i1].lpszFileName :=
          StrNew(PChar(ExtractFileName(FileName)));
        Attachments[i1].lpFileType := nil;
      end;
      MapiMessage.nFileCount := AttachCount;
      MapiMessage.lpFiles := @Attachments^;
    end;
    try
      if Mail.Values['subject'] <> '' then
        MapiMessage.lpszSubject := StrNew(PChar(Mail.Values['subject']));
      if Mail.Values['body'] <> '' then
        MapiMessage.lpszNoteText := StrNew(PChar(Mail.Values['body']));

      WndList := DisableTaskWindows(0);
      try
        Result := MapiSendMail(MAPI_Session, Handle,
        MapiMessage, MAPI_DIALOG, 0);
      finally
        EnableTaskWindows( WndList );
      end;
    finally
      for i1 := 0 to AttachCount - 1 do
      begin
        StrDispose(Attachments[i1].lpszPathName);
        StrDispose(Attachments[i1].lpszFileName);
      end;
    end;

    if Assigned(MapiMessage.lpszSubject) then
      StrDispose(MapiMessage.lpszSubject);
    if Assigned(MapiMessage.lpszNoteText) then
      StrDispose(MapiMessage.lpszNoteText);
    if Assigned(Receip.lpszAddress) then
      StrDispose(Receip.lpszAddress);
    if Assigned(Receip.lpszName) then
      StrDispose(Receip.lpszName);
  finally
    MapiLogOff(MAPI_Session, Handle, 0, 0);
  end;
end;

end.

