unit FileMappedBitmap;

interface

uses Windows, Graphics, LinarBitmap, MemUtils;

type
  TBitmapDataLocation = (bdlRAM, bdlSwapFile, bdlTempFile);

  TFileMappedBitmap = class(TLinearBitmap)
    protected
      MemoryMappedFile : TMemoryMappedFile;
      FMaximumMappedBlock : Integer;
      FMapFullImage : Boolean;
      FSize64 : Int64;
      function GetScanLineSafe(Y: Integer): Pointer; override;
      function GetPixelSafe(X,Y: Integer): Pointer;
      function GetPixel8(X, Y: Integer): Byte;
      procedure SetPixel8(X, Y: Integer; Value: Byte);
      function GetMaximumMappedBlock: Integer;
    public
      procedure New(Width,Height: Integer; PixFormat: TPixelFormat; DataStorage: TBitmapDataLocation; MapFullImage: Boolean=True);
      procedure SetStorage(KeepContents: Boolean; DataStorage: TBitmapDataLocation; MapFullImage: Boolean=True);
      procedure MapInPhysicalMemory;
      function InFile: Boolean;
      function MustUpdateScanLine: Boolean;
      procedure Dispose; override;
      procedure Assign(Other: TObject); override;
      property ScanLine[Y: Integer]: Pointer read GetScanLineSafe;
      property PixelSafe[X,Y: Integer]: Pointer read GetPixelSafe;
      property Pixel8[X,Y: Integer]: Byte read GetPixel8 write SetPixel8;
      property Size64: Int64 read FSize64;
      property MaximumMappedBlock: Integer read GetMaximumMappedBlock write FMaximumMappedBlock;
      procedure UnmapImage;
      procedure Clear(Value: Byte=0);
    end;

  TFileMappedBitmapStrip = class(TFileMappedBitmap)
    protected
      fYStart : Integer;
      function GetScanLineSafe(Y: Integer): Pointer; override;
    public
      constructor Create(Source: TFileMappedBitmap; YStart,Height: Integer);
      procedure Dispose; override;
    end;

  TFileMappedBitmapLoader = class(TBitmapLoader)
    protected
      // Returns true if the image is mapped in a file and not completely in memory
      function MustUpdateScanLine(Image: TLinearBitmap): Boolean;
    end;

implementation

uses SysUtils, SysConst, FileUtils, Math, MathUtils;

//==============================================================================================================================
// TFileMappedBitmapLoader
//==============================================================================================================================

function TFileMappedBitmapLoader.MustUpdateScanLine(Image: TLinearBitmap): Boolean;
begin
  Result:=(Image is TFileMappedBitmap) and TFileMappedBitmap(Image).MustUpdateScanLine;
end;

//==============================================================================================================================
// TFileMappedBitmap
//==============================================================================================================================

procedure TFileMappedBitmap.New(Width, Height: Integer; PixFormat: TPixelFormat; DataStorage: TBitmapDataLocation; MapFullImage: Boolean);
begin
  if FPresent and (FWidth=Width) and (FHeight=Height) and (PixelFormat=PixFormat) then
  begin
    SetStorage(False,DataStorage,MapFullImage);
    Exit;
  end;

  Dispose;

  if not (PixFormat in [pf8bit,pf16bit,pf24bit,pf32bit]) then raise ELinearBitmap.Create(rsInvalidPixelFormat);
  if (Width<1) or (Height<1) then raise ELinearBitmap.Create(rsInvalidBitmapSize);

  if PixFormat=pf8bit then
  begin
    fPixelSize:=1;
    if Palette=nil then GetMem(Palette,SizeOf(TPalette));
  end
  else
  begin
    if PixFormat=pf24bit then fPixelSize:=3
    else if PixFormat=pf16bit then fPixelSize:=2
    else fPixelSize:=4;
    if Assigned(Palette) then
    begin
      FreeMem(Palette);
      Palette:=nil;
    end;
  end;
  FSize64:=Int64(Width)*Height*fPixelSize;
  if FSize64>$7fffffff then FSize:=-1 // >2GB
  else FSize:=FSize64;
  FWidth:=Width; FHeight:=Height;
  FBytesPerLine:=Width*PixelSize;
  FPixelFormat:=PixFormat;
  FPresent:=True;
  try
    SetStorage(False,DataStorage,MapFullImage);
  except
    Dispose;
    raise;
  end;
end;

procedure TFileMappedBitmap.SetStorage(KeepContents: Boolean; DataStorage: TBitmapDataLocation; MapFullImage: Boolean);
var
  FileHandle : THandle;
begin
  if DataStorage=bdlRAM then // Allocate in RAM
  begin
    MapInPhysicalMemory;
  end
  else if not InFile then // Allocate in file
  begin
    FreeAndNil(MemoryMappedFile);
    if not KeepContents and Assigned(Map) then FreeAndNilData(Map);
    if not Present then Exit;

    if DataStorage=bdlSwapFile then
    begin
      if FSize64>$7ffffffe then raise ELinearBitmap.Create(SOutOfMemory);
      MemoryMappedFile:=TMemoryMappedFile.Create(Size+1,MapFullImage);
    end
    else
    begin
      FileHandle:=CreateFile(PChar(GetTempFileName),GENERIC_READ or GENERIC_WRITE,0,nil,CREATE_ALWAYS,FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE,0);
      if FileHandle=0 then RaiseLastOSError;
      MemoryMappedFile:=TMemoryMappedFile.Create(FileHandle,Size64+1,MapFullImage);
    end;
    FMapFullImage:=MapFullImage;

    if KeepContents and Assigned(Map) then
    begin
      Assert(MapFullImage);
      Move(Map^,MemoryMappedFile.Memory^,Size);
      FreeMem(Map);
    end;
    Map:=MemoryMappedFile.Memory;
  end
  else if MapFullImage<>FMapFullImage then
  begin
    Assert(Map=MemoryMappedFile.Memory);
    if MapFullImage then
    begin
      if FSize64>$7ffffffe then raise ELinearBitmap.Create(SOutOfMemory);
      MemoryMappedFile.SelectMappedRange(0,Size+1)
    end
    else MemoryMappedFile.UnmapFile;
    FMapFullImage:=MapFullImage;
    Map:=MemoryMappedFile.Memory;
  end;
end;

procedure TFileMappedBitmap.MapInPhysicalMemory;
begin
  if FSize64>$7ffffffe then raise ELinearBitmap.Create(SOutOfMemory);
  if MemoryMappedFile<>nil then
  begin
    if Map=MemoryMappedFile.Memory then
    begin
      Assert(FMapFullImage);
      GetMem(Map,Size+1);
      Move(MemoryMappedFile.Memory^,Map^,Size);
    end
    else GetMem(Map,Size+1);
    FreeAndNil(MemoryMappedFile);
  end
  else if Map=nil then GetMem(Map,Size+1);
  FMapFullImage:=False;
end;

procedure TFileMappedBitmap.Dispose;
begin
  if MemoryMappedFile<>nil then
  begin
    if Map=MemoryMappedFile.Memory then Map:=nil;
    FreeAndNil(MemoryMappedFile);
  end;
  FSize64:=0;
  FMapFullImage:=False;
  inherited;
end;

function TFileMappedBitmap.InFile: Boolean;
begin
  Result:=Assigned(MemoryMappedFile) and (MemoryMappedFile.Memory=Map);
end;

function TFileMappedBitmap.MustUpdateScanLine: Boolean;
begin
  Result:=Assigned(MemoryMappedFile) and not FMapFullImage;
end;

function TFileMappedBitmap.GetScanLineSafe(Y: Integer): Pointer;
var
  Offset : Int64;
  MapSize : DWord;
begin
  Assert((Y>=0) and (Y<Height));
  Offset:=Int64(Y)*DWord(BytesPerLine);
  if Assigned(MemoryMappedFile) and not FMapFullImage then
  begin
    if (Offset<MemoryMappedFile.MappedRangeFrom) or
       (Offset+BytesPerLine+1>=MemoryMappedFile.MappedRangeTo) then
    begin
      MapSize:=MaximumMappedBlock;
      if Offset+MapSize>MemoryMappedFile.Size then MapSize:=MemoryMappedFile.Size-Offset;
      MemoryMappedFile.SelectMappedRange(Offset,MapSize);
      Map:=MemoryMappedFile.Memory;
    end;
  end;
  Result:=@Map^[Offset];
end;

function TFileMappedBitmap.GetPixelSafe(X,Y: Integer): Pointer;
begin
  Result:=@PByteArray(GetScanLineSafe(Y))^[X*PixelSize];
end;

procedure TFileMappedBitmap.Clear(Value: Byte);
var
  Y : Integer;
begin
  if (MemoryMappedFile=nil) or FMapFullImage then
    inherited
  else
    for Y:=0 to Height-1 do
      FillChar(ScanLine[Y]^,BytesPerLine,Value);
end;

procedure TFileMappedBitmap.UnmapImage;
begin
  if MemoryMappedFile<>nil then
  begin
    FMapFullImage:=False;
    Map:=nil;
    MemoryMappedFile.UnmapFile;
  end;
end;

function TFileMappedBitmap.GetPixel8(X, Y: Integer): Byte;
begin
  if X<0 then X:=0
  else if X>=Width then X:=Width-1;
  if Y<0 then Y:=0
  else if Y>=Height then Y:=Height-1;
  Result:=PByteArray(GetScanLineSafe(Y))^[X];
end;

procedure TFileMappedBitmap.SetPixel8(X, Y: Integer; Value: Byte);
begin
  if (X>=0) and (X<Width) and (Y>=0) and (Y<Height) then
    PByteArray(GetScanLineSafe(Y))^[X]:=Value;
end;

procedure TFileMappedBitmap.Assign(Other: TObject);
var
  Y : Integer;
begin
  if Present and (Other is TLinearBitmap) and
     (Width=TLinearBitmap(Other).Width) and
     (Height=TLinearBitmap(Other).Height) and
     (PixelFormat=TLinearBitmap(Other).PixelFormat) then
  begin
    for Y:=0 to Height-1 do Move(TLinearBitmap(Other).ScanLineSafe[Y]^,ScanLineSafe[Y]^,BytesPerLine);
    if PixelFormat=pf8bit then Palette^:=TLinearBitmap(Other).Palette^;
  end
  else inherited;
end;

function TFileMappedBitmap.GetMaximumMappedBlock: Integer;
begin
  if FMaximumMappedBlock=0 then FMaximumMappedBlock:=64*1024*1024;
  Result:=FloorInt(FMaximumMappedBlock,BytesPerLine)+1;
  if Result>FMaximumMappedBlock then Dec(Result,BytesPerLine);
  if Result<BytesPerLine then Inc(Result,BytesPerLine);
end;

//==============================================================================================================================
// TFileMappedBitmapStrip
//==============================================================================================================================

constructor TFileMappedBitmapStrip.Create(Source: TFileMappedBitmap; YStart,Height: Integer);
begin
  if not Source.Present or (Height<=0) or (YStart+Height>Source.Height) then
    raise Exception.Create(rsInvalidBitmapSize);
  inherited Create;
  fWidth:=Source.Width;
  fHeight:=Height;
  fPixelFormat:=Source.PixelFormat;
  fBytesPerLine:=Source.BytesPerLine;
  fPixelSize:=Source.PixelSize;
  Palette:=Source.Palette;
  FSize64:=Height*BytesPerLine;
  if FSize64>$7fffffff then FSize:=-1 // >2GB
  else FSize:=Size64;
  fPresent:=True;
  FMapFullImage:=Source.FMapFullImage;
  fYStart:=YStart;
  if (Source.MemoryMappedFile=nil) or FMapFullImage then Map:=Source.Map
  else
  begin
    MemoryMappedFile:=Source.MemoryMappedFile;
    Map:=MemoryMappedFile.Memory;
  end;
end;

procedure TFileMappedBitmapStrip.Dispose;
begin
  Palette:=nil;
  MemoryMappedFile:=nil;
  Map:=nil;
  inherited;
end;

function TFileMappedBitmapStrip.GetScanLineSafe(Y: Integer): Pointer;
var
  Offset : Int64;
  MapSize : DWord;
begin
  Assert((Y>=0) and (Y<Height));
  Offset:=Int64(Y+fYStart)*DWord(BytesPerLine);
  if Assigned(MemoryMappedFile) then
  begin
    if (Offset<MemoryMappedFile.MappedRangeFrom) or
       (Offset+BytesPerLine+1>=MemoryMappedFile.MappedRangeTo) then
    begin
      MapSize:=MaximumMappedBlock;
      if Offset+MapSize>MemoryMappedFile.Size then MapSize:=MemoryMappedFile.Size-Offset;
      MemoryMappedFile.SelectMappedRange(Offset,MapSize);
      Map:=MemoryMappedFile.Memory;
    end;
  end;
  Result:=@Map^[Offset];
end;

end.

