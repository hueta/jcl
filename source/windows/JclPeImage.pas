{******************************************************************************}
{                                                                              }
{ Project JEDI Code Library (JCL)                                              }
{                                                                              }
{ The contents of this file are subject to the Mozilla Public License Version  }
{ 1.0 (the "License"); you may not use this file except in compliance with the }
{ License. You may obtain a copy of the License at http://www.mozilla.org/MPL/ }
{                                                                              }
{ Software distributed under the License is distributed on an "AS IS" basis,   }
{ WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for }
{ the specific language governing rights and limitations under the License.    }
{                                                                              }
{ The Original Code is JclPeImage.pas.                                         }
{                                                                              }
{ The Initial Developer of the Original Code is documented in the accompanying }
{ help file JCL.chm. Portions created by these individuals are Copyright (C)   }
{ of these individuals.                                                        }
{                                                                              }
{******************************************************************************}
{                                                                              }
{ This unit contains various PE file classes and support routines              }
{                                                                              }
{ Unit owner: Petr Vones                                                       }
{ Last modified: January 6, 2001                                               }
{                                                                              }
{******************************************************************************}

unit JclPeImage;

{$I JCL.INC}

{$WEAKPACKAGEUNIT ON}

interface

uses
  Windows, ActiveX, Classes, ImageHlp, SysUtils, TypInfo,
  {$IFDEF DELPHI5_UP}
  Contnrs,
  {$ENDIF DELPHI5_UP}
  JclBase, JclDateTime, JclFileUtils, JclStrings, JclSysInfo;

//------------------------------------------------------------------------------
// Missing winnt.h translations
//------------------------------------------------------------------------------

const
  IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT   = 13; // Delay load import descriptors
  IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR = 14; // COM run-time descriptor
  RT_HTML = MakeIntResource(23);

type

{$IFNDEF DELPHI5_UP}
  PImageExportDirectory = ^TImageExportDirectory;
  _IMAGE_EXPORT_DIRECTORY = packed record
    Characteristics: DWORD;
    TimeDateStamp: DWORD;
    MajorVersion: Word;
    MinorVersion: Word;
    Name: DWORD;
    Base: DWORD;
    NumberOfFunctions: DWORD;
    NumberOfNames: DWORD;
    AddressOfFunctions: DWORD;    // RVA from base of image
    AddressOfNames: DWORD;        // RVA from base of image
    AddressOfNameOrdinals: DWORD; // RVA from base of image
  end;
  TImageExportDirectory = _IMAGE_EXPORT_DIRECTORY;
  IMAGE_EXPORT_DIRECTORY = _IMAGE_EXPORT_DIRECTORY;
{$ENDIF DELPHI5_UP}

{ Non-COFF Object file header }

  PANonObjectHeader = ^TANonObjectHeader;
  ANON_OBJECT_HEADER = record
    Sig1: Word;            // Must be IMAGE_FILE_MACHINE_UNKNOWN
    Sig2: Word;            // Must be 0xffff
    Version: Word;         // >= 1 (implies the CLSID field is present)
    Machine: Word;
    TimeDateStamp: DWORD;
    ClassID: TCLSID;       // Used to invoke CoCreateInstance
    SizeOfData: DWORD;     // Size of data that follows the header
  end;
  TANonObjectHeader = ANON_OBJECT_HEADER;

{ Import format }

  PImageImportByName = ^TImageImportByName;
  _IMAGE_IMPORT_BY_NAME = packed record
    Hint: Word;
    Name: array [0..0] of Char;
  end;
  TImageImportByName = _IMAGE_IMPORT_BY_NAME;
  IMAGE_IMPORT_BY_NAME = _IMAGE_IMPORT_BY_NAME;

  PImageThunkData = ^TImageThunkData;
  _IMAGE_THUNK_DATA = packed record
    case Integer of
      0: (ForwarderString: DWORD;);      // PBYTE
      1: (Function_: DWORD;);            // PDWORD
      2: (Ordinal: DWORD;);
      3: (AddressOfData: DWORD;);        // PIMAGE_IMPORT_BY_NAME
  end;
  TImageThunkData = _IMAGE_THUNK_DATA;
  IMAGE_THUNK_DATA = _IMAGE_THUNK_DATA;

const
  IMAGE_ORDINAL_FLAG = $80000000;

function IMAGE_ORDINAL(Ordinal: DWORD): Word;

type
  PImageTlsDirectory = ^TImageTlsDirectory;
  _IMAGE_TLS_DIRECTORY = packed record
    StartAddressOfRawData: DWORD;
    EndAddressOfRawData: DWORD;
    AddressOfIndex: DWORD;                // PDWORD
    AddressOfCallBacks: DWORD;            // PIMAGE_TLS_CALLBACK *
    SizeOfZeroFill: DWORD;
    Characteristics: DWORD;
  end;
  TImageTlsDirectory = _IMAGE_TLS_DIRECTORY;
  IMAGE_TLS_DIRECTORY = _IMAGE_TLS_DIRECTORY;

  PImageImportDescriptor = ^TImageImportDescriptor;
  _IMAGE_IMPORT_DESCRIPTOR = record
    Characteristics: DWORD;  // 0 for terminating null import descriptor
                             // RVA to original unbound IAT (PIMAGE_THUNK_DATA)
    TimeDateStamp: DWORD;    // 0 if not bound,
                             // -1 if bound, and real date\time stamp
                             //     in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND)
                             // O.W. date/time stamp of DLL bound to (Old BIND)
    ForwarderChain: DWORD;   // -1 if no forwarders
    Name: DWORD;
    FirstThunk: DWORD;       // RVA to IAT (if bound this IAT has actual addresses)
  end;
  TImageImportDescriptor = _IMAGE_IMPORT_DESCRIPTOR;
  IMAGE_IMPORT_DESCRIPTOR = _IMAGE_IMPORT_DESCRIPTOR;

{ New format import descriptors pointed to by DataDirectory[ IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT ] }

  PImageBoundImportDescriptor = ^TImageBoundImportDescriptor;
  _IMAGE_BOUND_IMPORT_DESCRIPTOR = record
    TimeDateStamp: DWORD;
    OffsetModuleName: Word;
    NumberOfModuleForwarderRefs: Word;
    // Array of zero or more IMAGE_BOUND_FORWARDER_REF follows
  end;
  TImageBoundImportDescriptor = _IMAGE_BOUND_IMPORT_DESCRIPTOR;
  IMAGE_BOUND_IMPORT_DESCRIPTOR = _IMAGE_BOUND_IMPORT_DESCRIPTOR;

  PImageBoundForwarderRef = ^TImageBoundForwarderRef;
  _IMAGE_BOUND_FORWARDER_REF = record
    TimeDateStamp: DWORD;
    OffsetModuleName: Word;
    Reserved: Word;
  end;
  TImageBoundForwarderRef = _IMAGE_BOUND_FORWARDER_REF;
  IMAGE_BOUND_FORWARDER_REF = _IMAGE_BOUND_FORWARDER_REF;

{ Resource Format }

const
  IMAGE_RESOURCE_NAME_IS_STRING    = $80000000;
  IMAGE_RESOURCE_DATA_IS_DIRECTORY = $80000000;

type
  PImageResourceDirectory = ^TImageResourceDirectory;
  _IMAGE_RESOURCE_DIRECTORY = packed record
    Characteristics: DWORD;
    TimeDateStamp: DWORD;
    MajorVersion: Word;
    MinorVersion: Word;
    NumberOfNamedEntries: Word;
    NumberOfIdEntries: Word;
  end;
  TImageResourceDirectory = _IMAGE_RESOURCE_DIRECTORY;
  IMAGE_RESOURCE_DIRECTORY = _IMAGE_RESOURCE_DIRECTORY;

  PImageResourceDirectoryEntry = ^TImageResourceDirectoryEntry;
  _IMAGE_RESOURCE_DIRECTORY_ENTRY = packed record
    Name: DWORD;        // Or ID: Word (Union)
    OffsetToData: DWORD;
  end;
  TImageResourceDirectoryEntry = _IMAGE_RESOURCE_DIRECTORY_ENTRY;
  IMAGE_RESOURCE_DIRECTORY_ENTRY = _IMAGE_RESOURCE_DIRECTORY_ENTRY;

  PImageResourceDataEntry = ^TImageResourceDataEntry;
  _IMAGE_RESOURCE_DATA_ENTRY = packed record
    OffsetToData: DWORD;
    Size: DWORD;
    CodePage: DWORD;
    Reserved: DWORD;
  end;
  TImageResourceDataEntry = _IMAGE_RESOURCE_DATA_ENTRY;
  IMAGE_RESOURCE_DATA_ENTRY = _IMAGE_RESOURCE_DATA_ENTRY;

  PImageResourceDirStringU = ^TImageResourceDirStringU;
  _IMAGE_RESOURCE_DIR_STRING_U = packed record
    Length: Word;
    NameString: array [0..0] of WCHAR;
  end;
  TImageResourceDirStringU = _IMAGE_RESOURCE_DIR_STRING_U;
  IMAGE_RESOURCE_DIR_STRING_U = _IMAGE_RESOURCE_DIR_STRING_U;

{ Load Configuration Directory Entry }

  PImageLoadConfigDirectory = ^TImageLoadConfigDirectory;
  IMAGE_LOAD_CONFIG_DIRECTORY = packed record
    Characteristics: DWORD;
    TimeDateStamp: DWORD;
    MajorVersion: Word;
    MinorVersion: Word;
    GlobalFlagsClear: DWORD;
    GlobalFlagsSet: DWORD;
    CriticalSectionDefaultTimeout: DWORD;
    DeCommitFreeBlockThreshold: DWORD;
    DeCommitTotalFreeThreshold: DWORD;
    LockPrefixTable: DWORD; // VA
    MaximumAllocationSize: DWORD;
    VirtualMemoryThreshold: DWORD;
    ProcessHeapFlags: DWORD;
    ProcessAffinityMask: DWORD;
    CSDVersion: Word;
    Reserved1: Word;
    EditList: DWORD; // VA
    Reserved: array [0..0] of  DWORD;
  end;
  TImageLoadConfigDirectory = IMAGE_LOAD_CONFIG_DIRECTORY;

  PImgDelayDescr = ^TImgDelayDescr;
  ImgDelayDescr = packed record
    grAttrs: DWORD;                 // attributes
    szName: DWORD;                  // pointer to dll name
    phmod: PDWORD;                  // address of module handle
    pIAT: TImageThunkData;          // address of the IAT
    pINT: TImageThunkData;          // address of the INT
    pBoundIAT: TImageThunkData;     // address of the optional bound IAT
    pUnloadIAT: TImageThunkData;    // address of optional copy of original IAT
    dwTimeStamp: DWORD;             // 0 if not bound,
                                    // O.W. date/time stamp of DLL bound to (Old BIND)
  end;
  TImgDelayDescr = ImgDelayDescr;

{ Relocation }

  PImageBaseRelocation = ^TImageBaseRelocation;
  _IMAGE_BASE_RELOCATION = packed record
    VirtualAddress: DWORD;
    SizeOfBlock: DWORD;
  end;
  TImageBaseRelocation = _IMAGE_BASE_RELOCATION;
  IMAGE_BASE_RELOCATION =_IMAGE_BASE_RELOCATION;

const
  IMAGE_SIZEOF_BASE_RELOCATION   = 8;

  IMAGE_REL_BASED_ABSOLUTE       = 0;
  IMAGE_REL_BASED_HIGH           = 1;
  IMAGE_REL_BASED_LOW            = 2;
  IMAGE_REL_BASED_HIGHLOW        = 3;
  IMAGE_REL_BASED_HIGHADJ        = 4;
  IMAGE_REL_BASED_MIPS_JMPADDR   = 5;
  IMAGE_REL_BASED_SECTION        = 6;
  IMAGE_REL_BASED_REL32          = 7;

  IMAGE_REL_BASED_MIPS_JMPADDR16 = 9;
  IMAGE_REL_BASED_IA64_IMM64     = 9;
  IMAGE_REL_BASED_DIR64          = 10;
  IMAGE_REL_BASED_HIGH3ADJ       = 11;

{ Debug format }

  IMAGE_DEBUG_TYPE_BORLAND = 9;

//------------------------------------------------------------------------------
// Incorrect translations
//------------------------------------------------------------------------------

type
  // possibly Borland's header translation bug
  TLoadedImage = LoadedImage;

  PPImageSectionHeader = ^PImageSectionHeader;

  // wrong translation - LastRvaSection parameter is not var
  function ImageRvaToVa(NtHeaders: PImageNtHeaders; Base: Pointer;
    Rva: ULONG; LastRvaSection: PPImageSectionHeader): Pointer; stdcall;
    external 'imagehlp.dll' name 'ImageRvaToVa';

  // wrong translation - last parameter is incorrect
  function BindImageEx(Flags: DWORD; ImageName, DllPath, SymbolPath: LPSTR;
    StatusRoutine: TImagehlpStatusRoutine): Bool; stdcall;
    external 'imagehlp.dll' name 'BindImageEx';

  // wrong translation - last parameter is incorrect
  function ImageEnumerateCertificates(FileHandle: THandle; TypeFilter: Word;
    CertificateCount, Indices: PDWORD; IndexCount: DWORD): Bool; stdcall;
    external 'imagehlp.dll' name 'ImageEnumerateCertificates';

//------------------------------------------------------------------------------
// Smart name compare function
//------------------------------------------------------------------------------

type
  TJclSmartCompOption = (scSimpleCompare, scIgnoreCase);
  TJclSmartCompOptions = set of TJclSmartCompOption;

function PeStripFunctionAW(const FunctionName: string): string;

function PeSmartFunctionNameSame(const ComparedName, FunctionName: string;
  Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): Boolean;

//------------------------------------------------------------------------------
// Base list
//------------------------------------------------------------------------------

type
  EJclPeImageError = class (EJclError);

  TJclPeImage = class;

  TJclPeImageBaseList = class (TObjectList)
  private
    FImage: TJclPeImage;
  public
    constructor Create(AImage: TJclPeImage);
    property Image: TJclPeImage read FImage;
  end;

//------------------------------------------------------------------------------
// Images cache
//------------------------------------------------------------------------------

  TJclPeImagesCache = class (TObject)
  private
    FList: TStringList;
    function GetCount: Integer;
    function GetImages(const FileName: TFileName): TJclPeImage;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    property Images[const FileName: TFileName]: TJclPeImage read GetImages; default;
    property Count: Integer read GetCount;
  end;

//------------------------------------------------------------------------------
// Import section related classes
//------------------------------------------------------------------------------

  TJclPeImportSort = (isName, isOrdinal, isHint, isLibImport);
  TJclPeImportLibSort = (ilName, ilIndex);
  TJclPeImportKind = (ikImport, ikDelayImport, ikBoundImport);
  TJclPeResolveCheck = (icNotChecked, icResolved, icUnresolved);
  TJclPeLinkerProducer = (lrBorland, lrMicrosoft);
  // lrBorland   -> Delphi images
  // lrMicrosoft -> MSVC and BCB images

  TJclPeImportLibItem = class;

  TJclPeImportFuncItem = class (TObject)
  private
    FOrdinal: Word;
    FHint: Word;
    FImportLib: TJclPeImportLibItem;
    FName: PChar;
    FIndirectImportName: Boolean;
    FResolveCheck: TJclPeResolveCheck;
    function GetIsByOrdinal: Boolean;
    function GetName: string;
  protected
    procedure SetIndirectImportName(P: PChar);
  public
    destructor Destroy; override;
    property Ordinal: Word read FOrdinal;
    property Hint: Word read FHint;
    property ImportLib: TJclPeImportLibItem read FImportLib;
    property IndirectImportName: Boolean read FIndirectImportName;
    property IsByOrdinal: Boolean read GetIsByOrdinal;
    property Name: string read GetName;
    property ResolveCheck: TJclPeResolveCheck read FResolveCheck;
  end;

  TJclPeImportLibItem = class (TJclPeImageBaseList)
  private
    FImportDescriptor: Pointer;
    FImportDirectoryIndex: Integer;
    FImportKind: TJclPeImportKind;
    FLastSortType: TJclPeImportSort;
    FLastSortDescending: Boolean;
    FName: PChar;
    FSorted: Boolean;
    FTotalResolveCheck: TJclPeResolveCheck;
    FThunk: PImageThunkData;
    FThunkData: PImageThunkData;
    function GetCount: Integer;
    function GetFileName: TFileName;
    function GetItems(Index: Integer): TJclPeImportFuncItem;
    function GetOriginalName: string;
    function GetName: string;
  protected
    procedure CheckImports(ExportImage: TJclPeImage);
    procedure CreateList;
  public
    constructor Create(AImage: TJclPeImage);
    procedure SortList(SortType: TJclPeImportSort; Descending: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF});
    property Count: Integer read GetCount;
    property FileName: TFileName read GetFileName;
    property ImportDescriptor: Pointer read FImportDescriptor;
    property ImportDirectoryIndex: Integer read FImportDirectoryIndex;
    property ImportKind: TJclPeImportKind read FImportKind;
    property Items[Index: Integer]: TJclPeImportFuncItem read GetItems; default;
    property Name: string read GetName;
    property OriginalName: string read GetOriginalName;
    property ThunkData: PImageThunkData read FThunkData;
    property TotalResolveCheck: TJclPeResolveCheck read FTotalResolveCheck;
  end;

  TJclPeImportList = class (TJclPeImageBaseList)
  private
    FAllItemsList: TList;
    FFilterModuleName: string;
    FLastAllSortType: TJclPeImportSort;
    FLastAllSortDescending: Boolean;
    FLinkerProducer: TJclPeLinkerProducer;
    FParalelImportTable: array of Pointer;
    FUniqueNamesList: TStringList;
    function GetAllItemCount: Integer;
    function GetAllItems(Index: Integer): TJclPeImportFuncItem;
    function GetItems(Index: Integer): TJclPeImportLibItem;
    function GetUniqueLibItemCount: Integer;
    function GetUniqueLibItems(Index: Integer): TJclPeImportLibItem;
    function GetUniqueLibNames(Index: Integer): string;
    function GetUniqueLibItemFromName(const Name: string): TJclPeImportLibItem;
    procedure SetFilterModuleName(const Value: string);
  protected
    procedure CreateList;
    procedure RefreshAllItems;
  public
    constructor Create(AImage: TJclPeImage);
    destructor Destroy; override;
    procedure CheckImports(PeImageCache: TJclPeImagesCache {$IFDEF SUPPORTS_DEFAULTPARAMS} = nil {$ENDIF});
    function MakeBorlandImportTableForMappedImage: Boolean;
    function SmartFindName(const CompareName, LibName: string;
      Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): TJclPeImportFuncItem;
    procedure SortAllItemsList(SortType: TJclPeImportSort; Descending: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF});
    procedure SortList(SortType: TJclPeImportLibSort);
    procedure TryGetNamesForOrdinalImports;
    property AllItems[Index: Integer]: TJclPeImportFuncItem read GetAllItems;
    property AllItemCount: Integer read GetAllItemCount;
    property FilterModuleName: string read FFilterModuleName write SetFilterModuleName;
    property Items[Index: Integer]: TJclPeImportLibItem read GetItems; default;
    property LinkerProducer: TJclPeLinkerProducer read FLinkerProducer;
    property UniqueLibItemCount: Integer read GetUniqueLibItemCount;
    property UniqueLibItemFromName[const Name: string]: TJclPeImportLibItem read GetUniqueLibItemFromName;
    property UniqueLibItems[Index: Integer]: TJclPeImportLibItem read GetUniqueLibItems;
    property UniqueLibNames[Index: Integer]: string read GetUniqueLibNames;
  end;

//------------------------------------------------------------------------------
// Export section related classes
//------------------------------------------------------------------------------

  TJclPeExportSort = (esName, esOrdinal, esHint, esAddress, esForwarded,
    esAddrOrFwd, esSection);

  TJclPeExportFuncList = class;

  TJclPeExportFuncItem = class (TObject)
  private
    FAddress: DWORD;
    FExportList: TJclPeExportFuncList;
    FForwardedName: PChar;
    FForwardedDotPos: PChar;
    FHint: Word;
    FName: PChar;
    FOrdinal: Word;
    FResolveCheck: TJclPeResolveCheck;
    function GetIsForwarded: Boolean;
    function GetForwardedFuncName: string;
    function GetForwardedLibName: string;
    function GetForwardedFuncOrdinal: DWORD;
    function GetForwardedName: string;
    function GetName: string;
    function GetAddressOrForwardStr: string;
    function GetSectionName: string;
    function GetMappedAddress: Pointer;
  protected
    procedure FindForwardedDotPos;
  public
    property Address: DWORD read FAddress;
    property AddressOrForwardStr: string read GetAddressOrForwardStr;
    property IsForwarded: Boolean read GetIsForwarded;
    property ForwardedName: string read GetForwardedName;
    property ForwardedLibName: string read GetForwardedLibName;
    property ForwardedFuncOrdinal: DWORD read GetForwardedFuncOrdinal;
    property ForwardedFuncName: string read GetForwardedFuncName;
    property Hint: Word read FHint;
    property MappedAddress: Pointer read GetMappedAddress;
    property Name: string read GetName;
    property Ordinal: Word read FOrdinal;
    property ResolveCheck: TJclPeResolveCheck read FResolveCheck;
    property SectionName: string read GetSectionName;
  end;

  TJclPeExportFuncList = class (TJclPeImageBaseList)
  private
    FAnyForwards: Boolean;
    FBase: DWORD;
    FExportDir: PImageExportDirectory;
    FForwardedLibsList: TStringList;
    FFunctionCount: DWORD;
    FLastSortType: TJclPeExportSort;
    FLastSortDescending: Boolean;
    FSorted: Boolean;
    FTotalResolveCheck: TJclPeResolveCheck;
    function GetItems(Index: Integer): TJclPeExportFuncItem;
    function GetForwardedLibsList: TStrings;
    function GetItemFromAddress(Address: DWORD): TJclPeExportFuncItem;
    function GetItemFromOrdinal(Ordinal: DWORD): TJclPeExportFuncItem;
    function GetItemFromName(const Name: string): TJclPeExportFuncItem;
    function GetName: string;
  protected
    function CanPerformFastNameSearch: Boolean;
    procedure CreateList;
    property LastSortType: TJclPeExportSort read FLastSortType;
    property LastSortDescending: Boolean read FLastSortDescending;
    property Sorted: Boolean read FSorted;
  public
    constructor Create(AImage: TJclPeImage);
    destructor Destroy; override;
    procedure CheckForwards(PeImageCache: TJclPeImagesCache {$IFDEF SUPPORTS_DEFAULTPARAMS} = nil {$ENDIF});
    class function ItemName(Item: TJclPeExportFuncItem): string;
    function OrdinalValid(Ordinal: DWORD): Boolean;
    procedure PrepareForFastNameSearch;
    function SmartFindName(const CompareName: string;
      Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): TJclPeExportFuncItem;
    procedure SortList(SortType: TJclPeExportSort; Descending: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF});
    property AnyForwards: Boolean read FAnyForwards;
    property Base: DWORD read FBase;
    property ExportDir: PImageExportDirectory read FExportDir;
    property ForwardedLibsList: TStrings read GetForwardedLibsList;
    property FunctionCount: DWORD read FFunctionCount;
    property Items[Index: Integer]: TJclPeExportFuncItem read GetItems; default;
    property ItemFromAddress[Address: DWORD]: TJclPeExportFuncItem read GetItemFromAddress;
    property ItemFromName[const Name: string]: TJclPeExportFuncItem read GetItemFromName;
    property ItemFromOrdinal[Ordinal: DWORD]: TJclPeExportFuncItem read GetItemFromOrdinal;
    property Name: string read GetName;
    property TotalResolveCheck: TJclPeResolveCheck read FTotalResolveCheck;
  end;

//------------------------------------------------------------------------------
// Resource section related classes
//------------------------------------------------------------------------------

  TJclResourceType = (
    rtUnknown0,
    rtCursorEntry,
    rtBitmap,
    rtIconEntry,
    rtMenu,
    rtDialog,
    rtString,
    rtFontDir,
    rtFont,
    rtAccelerators,
    rtRCData,
    rtMessageTable,
    rtCursor,
    rtUnknown13,
    rtIcon,
    rtUnknown15,
    rtVersion,
    rtDlgInclude,
    rtUnknown18,
    rtPlugPlay,
    rtVxd,
    rtAniCursor,
    rtAniIcon,
    rtHmtl,
    rtUserDefined);

  TJclPeResourceList = class;
  TJclPeResourceItem = class;

  TJclPeResourceRawStream = class (TCustomMemoryStream)
  public
    constructor Create(AResourceItem: TJclPeResourceItem);
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

  TJclPeResourceItem = class (TObject)
  private
    FEntry: PImageResourceDirectoryEntry;
    FImage: TJclPeImage;
    FList: TJclPeResourceList;
    FParentItem: TJclPeResourceItem;
    function GetName: string;
    function GetIsDirectory: Boolean;
    function GetList: TJclPeResourceList;
    function GetDataEntry: PImageResourceDataEntry;
    function GetIsName: Boolean;
    function GetParameterName: string;
    function GetRawEntryData: Pointer;
    function GetResourceType: TJclResourceType;
    function GetResourceTypeStr: string;
    function GetRawEntryDataSize: Integer;
  protected
    function OffsetToRawData(Ofs: DWORD): DWORD;
    function Level1Item: TJclPeResourceItem;
    function SubDirData: PImageResourceDirectory;
  public
    destructor Destroy; override;
    property DataEntry: PImageResourceDataEntry read GetDataEntry;
    property Entry: PImageResourceDirectoryEntry read FEntry;
    property Image: TJclPeImage read FImage;
    property IsDirectory: Boolean read GetIsDirectory;
    property IsName: Boolean read GetIsName;
    property List: TJclPeResourceList read GetList;
    property Name: string read GetName;
    property ParameterName: string read GetParameterName; 
    property ParentItem: TJclPeResourceItem read FParentItem; 
    property RawEntryData: Pointer read GetRawEntryData;
    property RawEntryDataSize: Integer read GetRawEntryDataSize;
    property ResourceType: TJclResourceType read GetResourceType;
    property ResourceTypeStr: string read GetResourceTypeStr;
  end;

  TJclPeResourceList = class (TJclPeImageBaseList)
  private
    FDirectory: PImageResourceDirectory;
    function GetItems(Index: Integer): TJclPeResourceItem;
  protected
    procedure CreateList(AParentItem: TJclPeResourceItem);
  public
    constructor Create(ADirectory: PImageResourceDirectory; AImage: TJclPeImage;
      AParentItem: TJclPeResourceItem);
    property Directory: PImageResourceDirectory read FDirectory;
    property Items[Index: Integer]: TJclPeResourceItem read GetItems; default;
  end;

  TJclPeRootResourceList = class (TJclPeResourceList)
  public
    constructor Create(ADirectory: PImageResourceDirectory; AImage: TJclPeImage);
    function FindResource(ResourceType: TJclResourceType;
      const ResourceName: string {$IFDEF SUPPORTS_DEFAULTPARAMS} = '' {$ENDIF}): TJclPeResourceItem;
  end;

//------------------------------------------------------------------------------
// Relocation section related classes
//------------------------------------------------------------------------------

  TJclPeRelocation = record
    Address: Word;
    RelocType: Byte;
    VirtualAddress: DWORD;
  end;

  TJclPeRelocEntry = class (TObject)
  private
    FChunk: PImageBaseRelocation;
    FCount: Integer;
    function GetRelocations(Index: Integer): TJclPeRelocation;
    function GetSize: DWORD;
    function GetVirtualAddress: DWORD;
  public
    property Count: Integer read FCount;
    property Relocations[Index: Integer]: TJclPeRelocation read GetRelocations; default;
    property Size: DWORD read GetSize;
    property VirtualAddress: DWORD read GetVirtualAddress;
  end;

  TJclPeRelocList = class (TJclPeImageBaseList)
  private
    FAllItemCount: Integer;
    function GetItems(Index: Integer): TJclPeRelocEntry;
    function GetAllItems(Index: Integer): TJclPeRelocation;
  protected
    procedure CreateList;
  public
    constructor Create(AImage: TJclPeImage);
    property AllItems[Index: Integer]: TJclPeRelocation read GetAllItems;
    property AllItemCount: Integer read FAllItemCount;
    property Items[Index: Integer]: TJclPeRelocEntry read GetItems; default;
  end;

//------------------------------------------------------------------------------
// Debug section related classes
//------------------------------------------------------------------------------

  TJclPeDebugList = class (TJclPeImageBaseList)
  private
    function GetItems(Index: Integer): TImageDebugDirectory;
  protected
    procedure CreateList;
  public
    constructor Create(AImage: TJclPeImage);
    property Items[Index: Integer]: TImageDebugDirectory read GetItems; default;
  end;

//------------------------------------------------------------------------------
// PE Image
//------------------------------------------------------------------------------

  TJclPeHeader = (
    JclPeHeader_Signature,
    JclPeHeader_Machine,
    JclPeHeader_NumberOfSections,
    JclPeHeader_TimeDateStamp,
    JclPeHeader_PointerToSymbolTable,
    JclPeHeader_NumberOfSymbols,
    JclPeHeader_SizeOfOptionalHeader,
    JclPeHeader_Characteristics,
    JclPeHeader_Magic,
    JclPeHeader_LinkerVersion,
    JclPeHeader_SizeOfCode,
    JclPeHeader_SizeOfInitializedData,
    JclPeHeader_SizeOfUninitializedData,
    JclPeHeader_AddressOfEntryPoint,
    JclPeHeader_BaseOfCode,
    JclPeHeader_BaseOfData,
    JclPeHeader_ImageBase,
    JclPeHeader_SectionAlignment,
    JclPeHeader_FileAlignment,
    JclPeHeader_OperatingSystemVersion,
    JclPeHeader_ImageVersion,
    JclPeHeader_SubsystemVersion,
    JclPeHeader_Win32VersionValue,
    JclPeHeader_SizeOfImage,
    JclPeHeader_SizeOfHeaders,
    JclPeHeader_CheckSum,
    JclPeHeader_Subsystem,
    JclPeHeader_DllCharacteristics,
    JclPeHeader_SizeOfStackReserve,
    JclPeHeader_SizeOfStackCommit,
    JclPeHeader_SizeOfHeapReserve,
    JclPeHeader_SizeOfHeapCommit,
    JclPeHeader_LoaderFlags,
    JclPeHeader_NumberOfRvaAndSizes);

  TJclLoadConfig = (
    JclLoadConfig_Characteristics,
    JclLoadConfig_TimeDateStamp,
    JclLoadConfig_Version,
    JclLoadConfig_GlobalFlagsClear,
    JclLoadConfig_GlobalFlagsSet,
    JclLoadConfig_CriticalSectionDefaultTimeout,
    JclLoadConfig_DeCommitFreeBlockThreshold,
    JclLoadConfig_DeCommitTotalFreeThreshold,
    JclLoadConfig_LockPrefixTable,
    JclLoadConfig_MaximumAllocationSize,
    JclLoadConfig_VirtualMemoryThreshold,
    JclLoadConfig_ProcessHeapFlags,
    JclLoadConfig_ProcessAffinityMask,
    JclLoadConfig_CSDVersion,
    JclLoadConfig_Reserved1,
    JclLoadConfig_EditList,
    JclLoadConfig_Reserved
  );

  TJclPeFileProperties = record
    Size: DWORD;
    CreationTime: TDateTime;
    LastAccessTime: TDateTime;
    LastWriteTime: TDateTime;
    Attributes: Integer;
  end;

  TJclPeImageStatus = (stNotLoaded, stOk, stNotPE, stNotFound, stError);

  TJclPeImage = class (TObject)
  private
    FAttachedImage: Boolean;
    FDebugList: TJclPeDebugList;
    FFileName: TFileName;
    FImageSections: TStrings;
    FLoadedImage: TLoadedImage;
    FExportList: TJclPeExportFuncList;
    FImportList: TJclPeImportList;
    FNoExceptions: Boolean;
    FReadOnlyAccess: Boolean;
    FRelocationList: TJclPeRelocList;
    FResourceList: TJclPeRootResourceList;
    FResourceVA: DWORD;
    FStatus: TJclPeImageStatus;
    FVersionInfo: TJclFileVersionInfo;
    procedure ReadImageSections;
    function GetDebugList: TJclPeDebugList;
    function GetDescription: string;
    function GetDirectories(Directory: Word): TImageDataDirectory;
    function GetDirectoryExists(Directory: Word): Boolean;
    function GetExportList: TJclPeExportFuncList;
    function GetImportList: TJclPeImportList;
    function GetHeaderValues(Index: TJclPeHeader): string;
    function GetMappedAddress: DWORD;
    function GetOptionalHeader: TImageOptionalHeader;
    function GetRelocationList: TJclPeRelocList;
    function GetResourceList: TJclPeRootResourceList;
    function GetLoadConfigValues(Index: TJclLoadConfig): string;
    function GetFileProperties: TJclPeFileProperties;
    function GetUnusedHeaderBytes: TImageDataDirectory;
    function GetVersionInfo: TJclFileVersionInfo;
    function GetImageSectionCount: Integer;
    function GetImageSectionHeaders(Index: Integer): TImageSectionHeader;
    function GetImageSectionNames(Index: Integer): string;
    function GetImageSectionNameFromRva(const Rva: DWORD): string;
    function GetVersionInfoAvailable: Boolean;
    procedure SetFileName(const Value: TFileName);
  protected
    procedure AfterOpen; dynamic;
    procedure CheckNotAttached;
    procedure Clear; dynamic;
    function ExpandModuleName(const ModuleName: string): TFileName;
    procedure RaiseStatusException;
    property ReadOnlyAccess: Boolean read FReadOnlyAccess write FReadOnlyAccess;
  public
    constructor Create(ANoExceptions: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF});
    destructor Destroy; override;
    procedure AttachLoadedModule(const Handle: HMODULE);
    function CalculateCheckSum: DWORD;
    function DirectoryEntryToData(Directory: Word): Pointer;
    function GetSectionHeader(const SectionName: string; var Header: PImageSectionHeader): Boolean;
    function GetSectionName(const Header: PImageSectionHeader): string;
    function IsSystemImage: Boolean;
    function RawToVa(Raw: DWORD): Pointer;
    function RvaToSection(Rva: DWORD): PImageSectionHeader;
    function RvaToVa(Rva: DWORD): Pointer;
    function StatusOK: Boolean;
    procedure TryGetNamesForOrdinalImports;
    function VerifyCheckSum: Boolean;
    class function DebugTypeNames(DebugType: DWORD): string;
    class function DirectoryNames(Directory: Word): string;
    class function ExpandBySearchPath(const ModuleName, BasePath: string): TFileName;
    class function HeaderNames(Index: TJclPeHeader): string;
    class function LoadConfigNames(Index: TJclLoadConfig): string;
    class function ShortSectionInfo(Characteristics: DWORD): string;
    {$IFDEF SUPPORTS_INT64}
    class function StampToDateTime(TimeDateStamp: DWORD): TDateTime;
    {$ENDIF SUPPORTS_INT64}
    property AttachedImage: Boolean read FAttachedImage;
    property DebugList: TJclPeDebugList read GetDebugList;
    property Description: string read GetDescription;
    property Directories[Directory: Word]: TImageDataDirectory read GetDirectories;
    property DirectoryExists[Directory: Word]: Boolean read GetDirectoryExists;
    property ExportList: TJclPeExportFuncList read GetExportList;
    property FileName: TFileName read FFileName write SetFileName;
    property FileProperties: TJclPeFileProperties read GetFileProperties;
    property HeaderValues[Index: TJclPeHeader]: string read GetHeaderValues;
    property ImageSectionCount: Integer read GetImageSectionCount;
    property ImageSectionHeaders[Index: Integer]: TImageSectionHeader read GetImageSectionHeaders;
    property ImageSectionNames[Index: Integer]: string read GetImageSectionNames;
    property ImageSectionNameFromRva[const Rva: DWORD]: string read GetImageSectionNameFromRva;
    property ImportList: TJclPeImportList read GetImportList;
    property LoadConfigValues[Index: TJclLoadConfig]: string read GetLoadConfigValues;
    property LoadedImage: TLoadedImage read FLoadedImage;
    property MappedAddress: DWORD read GetMappedAddress;
    property OptionalHeader: TImageOptionalHeader read GetOptionalHeader;
    property RelocationList: TJclPeRelocList read GetRelocationList;
    property ResourceList: TJclPeRootResourceList read GetResourceList;
    property Status: TJclPeImageStatus read FStatus;
    property UnusedHeaderBytes: TImageDataDirectory read GetUnusedHeaderBytes;
    property VersionInfo: TJclFileVersionInfo read GetVersionInfo;
    property VersionInfoAvailable: Boolean read GetVersionInfoAvailable;
  end;

//------------------------------------------------------------------------------
// Borland Delphi PE Image specific information
//------------------------------------------------------------------------------

  TJclPePackageInfo = class (TObject)
  private
    FContains: TStrings;
    FRequires: TStrings;
    FFlags: Integer;
    function GetContainsCount: Integer;
    function GetContainsFlags(Index: Integer): Byte;
    function GetContainsNames(Index: Integer): string;
    function GetRequiresCount: Integer;
    function GetRequiresNames(Index: Integer): string;
  protected
    procedure ReadPackageInfo(ALibHandle: THandle);
  public
    constructor Create(ALibHandle: THandle);
    destructor Destroy; override;
    class function PackageModuleTypeToString(Flags: Integer): string;
    class function PackageOptionsToString(Flags: Integer): string;
    class function ProducerToString(Flags: Integer): string;
    class function UnitInfoFlagsToString(UnitFlags: Byte): string;
    property Contains: TStrings read FContains;
    property ContainsCount: Integer read GetContainsCount;
    property ContainsNames[Index: Integer]: string read GetContainsNames;
    property ContainsFlags[Index: Integer]: Byte read GetContainsFlags;
    property Flags: Integer read FFlags;
    property Requires: TStrings read FRequires;
    property RequiresCount: Integer read GetRequiresCount;
    property RequiresNames[Index: Integer]: string read GetRequiresNames;
  end;

  TJclPeBorImage = class (TJclPeImage)
  private
    FIsPackage: Boolean;
    FIsBorlandImage: Boolean;
    FLibHandle: THandle;
    FPackageDescription: string;
    FPackageInfo: TJclPePackageInfo;
    function GetIsTD32DebugPresent: Boolean;
    function GetLibHandle: THandle;
    function GetPackageInfo: TJclPePackageInfo;
  protected
    procedure AfterOpen; override;
    procedure Clear; override;
  public
    function FreeLibHandle: Boolean;
    property IsTD32DebugPresent: Boolean read GetIsTD32DebugPresent;
    property IsBorlandImage: Boolean read FIsBorlandImage;
    property IsPackage: Boolean read FIsPackage;
    property LibHandle: THandle read GetLibHandle;
    property PackageDescription: string read FPackageDescription;
    property PackageInfo: TJclPePackageInfo read GetPackageInfo;
  end;

//------------------------------------------------------------------------------
// Threaded function search
//------------------------------------------------------------------------------

  TJclPeNameSearchOption = (seImports, seDelayImports, seBoundImports, seExports);
  TJclPeNameSearchOptions = set of TJclPeNameSearchOption;

  TJclPeNameSearchNotifyEvent = procedure (Sender: TObject; PeImage: TJclPeImage) of object;
  TJclPeNameSearchFoundEvent = procedure (Sender: TObject; const FileName: TFileName;
    const FunctionName: string; Option: TJclPeNameSearchOption) of object;

  TJclPeNameSearch = class (TThread)
  private
    F_FileName: TFileName;
    F_FunctionName: string;
    F_Option: TJclPeNameSearchOption;
    FFunctionName: string;
    FOptions: TJclPeNameSearchOptions;
    FPath: string;
    FPeImage: TJclPeImage;
    FOnFound: TJclPeNameSearchFoundEvent;
    FOnProcessFile: TJclPeNameSearchNotifyEvent;
  protected
    function CompareName(const FunctionName, ComparedName: string): Boolean; virtual;
    procedure DoFound;
    procedure DoProcessFile;
    procedure Execute; override;
  public
    constructor Create(const FunctionName, Path: string;
      Options: TJclPeNameSearchOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [seImports, seExports] {$ENDIF});
    procedure Start;
    property OnFound: TJclPeNameSearchFoundEvent read FOnFound write FOnFound;
    property OnProcessFile: TJclPeNameSearchNotifyEvent read FOnProcessFile write FOnProcessFile;
  end;

//------------------------------------------------------------------------------
// PE Image miscellaneous functions
//------------------------------------------------------------------------------

type
  TJclRebaseImageInfo = record
    OldImageSize: DWORD;
    OldImageBase: DWORD;
    NewImageSize: DWORD;
    NewImageBase: DWORD;
  end;

function IsValidPeFile(const FileName: TFileName): Boolean;

function PeCreateNameHintTable(const FileName: TFileName): Boolean;

function PeRebaseImage(const ImageName: TFileName;
  NewBase: DWORD {$IFDEF SUPPORTS_DEFAULTPARAMS} = 0 {$ENDIF};
  TimeStamp: DWORD {$IFDEF SUPPORTS_DEFAULTPARAMS} = 0 {$ENDIF};
  MaxNewSize: DWORD {$IFDEF SUPPORTS_DEFAULTPARAMS} = 0 {$ENDIF}): TJclRebaseImageInfo;

function PeUpdateCheckSum(const FileName: TFileName): Boolean;

//------------------------------------------------------------------------------
// Various simple PE Image functions
//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_DYNAMICARRAYS}
type
  TJclStringArray = array of string;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

function PeDoesExportFunction(const FileName: TFileName; const FunctionName: string;
  Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): Boolean;

function PeIsExportFunctionForwardedEx(const FileName: TFileName; const FunctionName: string;
  var ForwardedName: string; Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): Boolean;
function PeIsExportFunctionForwarded(const FileName: TFileName; const FunctionName: string;
  Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): Boolean;

function PeDoesImportFunction(const FileName: TFileName; const FunctionName: string;
  const LibraryName: string {$IFDEF SUPPORTS_DEFAULTPARAMS} = '' {$ENDIF};
  Options: TJclSmartCompOptions {$IFDEF SUPPORTS_DEFAULTPARAMS} = [] {$ENDIF}): Boolean;

function PeDoesImportLibrary(const FileName: TFileName; const LibraryName: string;
  Recursive: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF}): Boolean;

function PeImportedLibraries(const FileName: TFileName; LibrariesList: TStrings;
  Recursive: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF};
  FullPathName: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF}): Boolean;
{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeImportedLibrariesArray(const FileName: TFileName; var LibrariesList: TJclStringArray;
  Recursive: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF};
  FullPathName: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF}): Boolean;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

function PeImportedFunctions(const FileName: TFileName; FunctionsList: TStrings;
  const LibraryName: string {$IFDEF SUPPORTS_DEFAULTPARAMS} = '' {$ENDIF};
  IncludeLibNames: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF}): Boolean;
{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeImportedFunctionsArray(const FileName: TFileName; var FunctionsList: TJclStringArray;
  const LibraryName: string {$IFDEF SUPPORTS_DEFAULTPARAMS} = '' {$ENDIF};
  IncludeLibNames: Boolean {$IFDEF SUPPORTS_DEFAULTPARAMS} = False {$ENDIF}): Boolean;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

function PeExportedFunctions(const FileName: TFileName; FunctionsList: TStrings): Boolean;
{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeExportedFunctionsArray(const FileName: TFileName; var FunctionsList: TJclStringArray): Boolean;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

function PeGetNtHeaders(const FileName: TFileName; var NtHeaders: TImageNtHeaders): Boolean;

function PeVerifyCheckSum(const FileName: TFileName): Boolean;

//------------------------------------------------------------------------------
// Mapped image related routines
//------------------------------------------------------------------------------

function PeMapImgNtHeaders(const BaseAddress: Pointer): PImageNtHeaders;

function PeMapImgLibraryName(const BaseAddress: Pointer): string;

function PeMapImgSections(const NtHeaders: PImageNtHeaders): PImageSectionHeader;

function PeMapImgFindSection(const NtHeaders: PImageNtHeaders;
  const SectionName: string): PImageSectionHeader;

type
  TJclPeSectionStream = class (TCustomMemoryStream)
  private
    FInstance: HMODULE;
    FSectionHeader: TImageSectionHeader;
    procedure Initialize(Instance: HMODULE; const ASectionName: string);
  public
    constructor Create(Instance: HMODULE; const ASectionName: string);
    function Write(const Buffer; Count: Longint): Longint; override;
    property Instance: HMODULE read FInstance;
    property SectionHeader: TImageSectionHeader read FSectionHeader;
  end;

//------------------------------------------------------------------------------
// API hooking classes
//------------------------------------------------------------------------------

type
  TJclPeMapImgHookItem = class (TObject)
  private
    FBaseAddress: Pointer;
    FFunctionName: string;
    FModuleName: string;
    FNewAddress: Pointer;
    FOriginalAddress: Pointer;
    FList: TObjectList;
  protected
    function InternalUnhook: Boolean;
  public
    destructor Destroy; override;
    function Unhook: Boolean;
    property BaseAddress: Pointer read FBaseAddress;
    property FunctionName: string read FFunctionName;
    property ModuleName: string read FModuleName;
    property NewAddress: Pointer read FNewAddress;
    property OriginalAddress: Pointer read FOriginalAddress;
  end;

  TJclPeMapImgHooks = class (TObjectList)
  private
    function GetItems(Index: Integer): TJclPeMapImgHookItem;
    function GetItemFromOriginalAddress(OriginalAddress: Pointer): TJclPeMapImgHookItem;
    function GetItemFromNewAddress(NewAddress: Pointer): TJclPeMapImgHookItem;
  public
    function HookImport(Base: Pointer; const ModuleName, FunctionName: string;
      NewAddress: Pointer; var OriginalAddress: Pointer): Boolean;
    class function IsWin9xDebugThunk(P: Pointer): Boolean; { TODO -cDOC : Hallvard Vassbotn }
    class function ReplaceImport(Base: Pointer; ModuleName: string; FromProc, ToProc: Pointer): Boolean; { TODO -cDOC : Hallvard Vassbotn }
    function UnhookByNewAddress(NewAddress: Pointer): Boolean;
    property Items[Index: Integer]: TJclPeMapImgHookItem read GetItems; default;
    property ItemFromOriginalAddress[OriginalAddress: Pointer]: TJclPeMapImgHookItem read GetItemFromOriginalAddress;
    property ItemFromNewAddress[NewAddress: Pointer]: TJclPeMapImgHookItem read GetItemFromNewAddress;
  end;

//------------------------------------------------------------------------------
// Image access under a debbuger
//------------------------------------------------------------------------------

function PeDbgImgNtHeaders(ProcessHandle: THandle; BaseAddress: Pointer;
  var NtHeaders: TImageNtHeaders): Boolean;

function PeDbgImgLibraryName(ProcessHandle: THandle; BaseAddress: Pointer;
  var Name: string): Boolean;

//------------------------------------------------------------------------------
// Borland name unmangling for Delphi packages
//------------------------------------------------------------------------------

type
  TJclBorUmSymbolKind = (skData, skFunction, skConstructor, skDestructor, skRTTI, skVTable);
  TJclBorUmSymbolModifier = (smQualified, smLinkProc);
  TJclBorUmSymbolModifiers = set of TJclBorUmSymbolModifier;
  TJclBorUmDescription = record
    Kind: TJclBorUmSymbolKind;
    Modifiers: TJclBorUmSymbolModifiers;
  end;
  TJclBorUmResult = (urOk, urNotMangled, urMicrosoft, urError);
  TJclPeUmResult = (umNotMangled, umBorland, umMicrosoft);

function PeBorUnmangleName(const Name: string; var Unmangled: string;
  var Description: TJclBorUmDescription; var BasePos: Integer): TJclBorUmResult; overload;
function PeBorUnmangleName(const Name: string; var Unmangled: string;
  var Description: TJclBorUmDescription): TJclBorUmResult; overload;
function PeBorUnmangleName(const Name: string; var Unmangled: string): TJclBorUmResult; overload;
function PeBorUnmangleName(const Name: string): string; overload;

function PeIsNameMangled(const Name: string): TJclPeUmResult;

function PeUnmangleName(const Name: string; var Unmangled: string): TJclPeUmResult;

//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_EXTSYM}
  {$EXTERNALSYM IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT}
  {$EXTERNALSYM IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR}
  {$EXTERNALSYM RT_HTML}
{$IFNDEF DELPHI5_UP}
  {$EXTERNALSYM _IMAGE_EXPORT_DIRECTORY}
  {$EXTERNALSYM IMAGE_EXPORT_DIRECTORY}
{$ENDIF DELPHI5_UP}
  {$EXTERNALSYM ANON_OBJECT_HEADER}
  {$EXTERNALSYM _IMAGE_IMPORT_BY_NAME}
  {$EXTERNALSYM IMAGE_IMPORT_BY_NAME}
  {$EXTERNALSYM _IMAGE_THUNK_DATA}
  {$EXTERNALSYM IMAGE_THUNK_DATA}
  {$EXTERNALSYM IMAGE_ORDINAL_FLAG}
  {$EXTERNALSYM IMAGE_ORDINAL}
  {$EXTERNALSYM _IMAGE_TLS_DIRECTORY}
  {$EXTERNALSYM IMAGE_TLS_DIRECTORY}
  {$EXTERNALSYM _IMAGE_IMPORT_DESCRIPTOR}
  {$EXTERNALSYM IMAGE_IMPORT_DESCRIPTOR}
  {$EXTERNALSYM _IMAGE_BOUND_IMPORT_DESCRIPTOR}
  {$EXTERNALSYM IMAGE_BOUND_IMPORT_DESCRIPTOR}
  {$EXTERNALSYM _IMAGE_BOUND_FORWARDER_REF}
  {$EXTERNALSYM IMAGE_BOUND_FORWARDER_REF}
  {$EXTERNALSYM IMAGE_RESOURCE_NAME_IS_STRING}
  {$EXTERNALSYM IMAGE_RESOURCE_DATA_IS_DIRECTORY}
  {$EXTERNALSYM _IMAGE_RESOURCE_DIRECTORY}
  {$EXTERNALSYM IMAGE_RESOURCE_DIRECTORY}
  {$EXTERNALSYM _IMAGE_RESOURCE_DIRECTORY_ENTRY}
  {$EXTERNALSYM IMAGE_RESOURCE_DIRECTORY_ENTRY}
  {$EXTERNALSYM _IMAGE_RESOURCE_DATA_ENTRY}
  {$EXTERNALSYM IMAGE_RESOURCE_DATA_ENTRY}
  {$EXTERNALSYM _IMAGE_RESOURCE_DIR_STRING_U}
  {$EXTERNALSYM IMAGE_RESOURCE_DIR_STRING_U}
  {$EXTERNALSYM IMAGE_LOAD_CONFIG_DIRECTORY}
  {$EXTERNALSYM ImgDelayDescr}
  {$EXTERNALSYM _IMAGE_BASE_RELOCATION}
  {$EXTERNALSYM IMAGE_BASE_RELOCATION}
  {$EXTERNALSYM IMAGE_SIZEOF_BASE_RELOCATION}
  {$EXTERNALSYM IMAGE_REL_BASED_ABSOLUTE}
  {$EXTERNALSYM IMAGE_REL_BASED_HIGH}
  {$EXTERNALSYM IMAGE_REL_BASED_LOW}
  {$EXTERNALSYM IMAGE_REL_BASED_HIGHLOW}
  {$EXTERNALSYM IMAGE_REL_BASED_HIGHADJ}
  {$EXTERNALSYM IMAGE_REL_BASED_MIPS_JMPADDR}
  {$EXTERNALSYM IMAGE_REL_BASED_SECTION}
  {$EXTERNALSYM IMAGE_REL_BASED_REL32}
  {$EXTERNALSYM IMAGE_REL_BASED_MIPS_JMPADDR16}
  {$EXTERNALSYM IMAGE_REL_BASED_IA64_IMM64}
  {$EXTERNALSYM IMAGE_REL_BASED_DIR64}
  {$EXTERNALSYM IMAGE_REL_BASED_HIGH3ADJ}
  {$EXTERNALSYM IMAGE_DEBUG_TYPE_BORLAND}
  {$EXTERNALSYM ImageRvaToVa}
  {$EXTERNALSYM BindImageEx}
  {$EXTERNALSYM ImageEnumerateCertificates}
{$ENDIF SUPPORTS_EXTSYM}

implementation

uses
  Consts,
  JclResources, JclSysUtils;

//------------------------------------------------------------------------------

function IMAGE_ORDINAL(Ordinal: DWORD): Word;
begin
  Result := Ordinal and $FFFF;
end;

//------------------------------------------------------------------------------

function GetVersionString(HiV, LoV: Word): string;
begin
  Result := Format('%u.%.2u', [HiV, LoV]);
end;

//==============================================================================
// Smart name compare function
//==============================================================================

function PeStripFunctionAW(const FunctionName: string): string;
var
  L: Integer;
begin
  Result := FunctionName;
  L := Length(Result);
  if (L > 1) and (Result[L] in ['A', 'W']) and
    (Result[L - 1] in ['a'..'z', '_', '0'..'9']) then
    Delete(Result, L, 1);
end;

//------------------------------------------------------------------------------

function PeSmartFunctionNameSame(const ComparedName, FunctionName: string;
  Options: TJclSmartCompOptions): Boolean;
var
  S: string;
begin
  if scIgnoreCase in Options then
    Result := StrSame(FunctionName, ComparedName)
  else
    Result := (FunctionName = ComparedName);
  if (not Result) and not (scSimpleCompare in Options) then
  begin
    if Length(FunctionName) > 0 then
    begin
      S := PeStripFunctionAW(FunctionName);
      if scIgnoreCase in Options then
        Result := StrSame(S, ComparedName)
      else
        Result := (S = ComparedName);
    end
    else
      Result := False;
  end;
end;

//==============================================================================
// TJclPeImagesCache
//==============================================================================

procedure TJclPeImagesCache.Clear;
var
  I: Integer;
begin
  with FList do
    for I := 0 to Count - 1 do
      Objects[I].Free;
  FList.Clear;
end;

//------------------------------------------------------------------------------

constructor TJclPeImagesCache.Create;
begin
  inherited Create;
  FList := TStringList.Create;
  FList.Sorted := True;
  FList.Duplicates := dupIgnore;
end;

//------------------------------------------------------------------------------

destructor TJclPeImagesCache.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeImagesCache.GetCount: Integer;
begin
  Result := FList.Count;
end;

//------------------------------------------------------------------------------

function TJclPeImagesCache.GetImages(const FileName: TFileName): TJclPeImage;
var
  I: Integer;
begin
  I := FList.IndexOf(FileName);
  if I = -1 then
  begin
    Result := TJclPeImage.Create(True);
    Result.FileName := FileName;
    FList.AddObject(FileName, Result);
  end
  else
    Result := TJclPeImage(FList.Objects[I]);
end;

//==============================================================================
// TJclPeImageBaseList
//==============================================================================

constructor TJclPeImageBaseList.Create(AImage: TJclPeImage);
begin
  inherited Create(True);
  FImage := AImage;
end;

//==============================================================================
// Import sort functions
//==============================================================================

function ImportSortByName(Item1, Item2: Pointer): Integer;
begin
  Result := StrComp(TJclPeImportFuncItem(Item1).FName, TJclPeImportFuncItem(Item2).FName);
  if Result = 0 then
    Result := StrComp(TJclPeImportFuncItem(Item1).ImportLib.FName, TJclPeImportFuncItem(Item2).ImportLib.FName);
  if Result = 0 then
    Result := TJclPeImportFuncItem(Item1).Ordinal - TJclPeImportFuncItem(Item2).Ordinal;
end;

function ImportSortByNameDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ImportSortByName(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ImportSortByHint(Item1, Item2: Pointer): Integer;
begin
  Result := TJclPeImportFuncItem(Item1).Hint - TJclPeImportFuncItem(Item2).Hint;
end;

function ImportSortByHintDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ImportSortByHint(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ImportSortByDll(Item1, Item2: Pointer): Integer;
begin
  Result := AnsiCompareStr(TJclPeImportFuncItem(Item1).ImportLib.Name,
    TJclPeImportFuncItem(Item2).ImportLib.Name);
  if Result = 0 then
    Result := ImportSortByName(Item1, Item2);
end;

function ImportSortByDllDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ImportSortByDll(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ImportSortByOrdinal(Item1, Item2: Pointer): Integer;
begin
  Result := StrComp(TJclPeImportFuncItem(Item1).ImportLib.FName,
    TJclPeImportFuncItem(Item2).ImportLib.FName);
  if Result = 0 then
    Result := TJclPeImportFuncItem(Item1).Ordinal -  TJclPeImportFuncItem(Item2).Ordinal;
end;

function ImportSortByOrdinalDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ImportSortByOrdinal(Item2, Item1);
end;

//------------------------------------------------------------------------------

function GetImportSortFunction(SortType: TJclPeImportSort; Descending: Boolean): TListSortCompare;
const
  SortFunctions: array [TJclPeImportSort, Boolean] of TListSortCompare =
    ((ImportSortByName, ImportSortByNameDESC),
     (ImportSortByOrdinal, ImportSortByOrdinalDESC),
     (ImportSortByHint, ImportSortByHintDESC),
     (ImportSortByDll, ImportSortByDllDESC)
    );
begin
  Result := SortFunctions[SortType, Descending];
end;

//------------------------------------------------------------------------------

function ImportLibSortByIndex(Item1, Item2: Pointer): Integer;
begin
  Result := TJclPeImportLibItem(Item1).ImportDirectoryIndex -
    TJclPeImportLibItem(Item2).ImportDirectoryIndex;
end;

//------------------------------------------------------------------------------

function ImportLibSortByName(Item1, Item2: Pointer): Integer;
begin
  Result := AnsiCompareStr(TJclPeImportLibItem(Item1).Name, TJclPeImportLibItem(Item2).Name);
  if Result = 0 then
    Result := ImportLibSortByIndex(Item1, Item2);
end;

//------------------------------------------------------------------------------

function GetImportLibSortFunction(SortType: TJclPeImportLibSort): TListSortCompare;
const
  SortFunctions: array [TJclPeImportLibSort] of TListSortCompare =
    (ImportLibSortByName, ImportLibSortByIndex);
begin
  Result := SortFunctions[SortType];
end;

//==============================================================================
// TJclPeImportFuncItem
//==============================================================================

destructor TJclPeImportFuncItem.Destroy;
begin
  SetIndirectImportName(nil);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeImportFuncItem.GetIsByOrdinal: Boolean;
begin
  Result := FOrdinal <> 0;
end;

//------------------------------------------------------------------------------

function TJclPeImportFuncItem.GetName: string;
begin
  Result := FName;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportFuncItem.SetIndirectImportName(P: PChar);
begin
  if FIndirectImportName then
  begin
    StrDispose(FName);
    FIndirectImportName := False;
    FName := '';
  end;
  if P <> nil then
  begin
    FName := StrNew(P);
    FIndirectImportName := True;
  end;
end;

//==============================================================================
// TJclPeImportLibItem
//==============================================================================

procedure TJclPeImportLibItem.CheckImports(ExportImage: TJclPeImage);
var
  I: Integer;
  ExportList: TJclPeExportFuncList;
begin
  if ExportImage.StatusOK then
  begin
    FTotalResolveCheck := icResolved;
    ExportList := ExportImage.ExportList;
    for I := 0 to Count - 1 do
    begin
      with Items[I] do
        if IsByOrdinal then
        begin
          if ExportList.OrdinalValid(Ordinal) then
            FResolveCheck := icResolved
          else
          begin
            FResolveCheck := icUnresolved;
            Self.FTotalResolveCheck := icUnresolved;
          end;
        end
        else
        begin
          if ExportList.ItemFromName[Items[I].Name] <> nil then
            FResolveCheck := icResolved
          else
          begin
            FResolveCheck := icUnresolved;
            Self.FTotalResolveCheck := icUnresolved;
          end;
        end;
    end;
  end
  else
  begin
    FTotalResolveCheck := icUnresolved;
    for I := 0 to Count - 1 do
      Items[I].FResolveCheck := icUnresolved;
  end;
end;

//------------------------------------------------------------------------------

constructor TJclPeImportLibItem.Create(AImage: TJclPeImage);
begin
  inherited;
  FTotalResolveCheck := icNotChecked;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportLibItem.CreateList;
var
  FuncItem: TJclPeImportFuncItem;
  ImageBase: DWORD;
  OrdinalName: PImageImportByName;
begin
  if FThunk = nil then
    Exit;
  ImageBase := Image.OptionalHeader.ImageBase;
  while FThunk^.Function_ <> 0 do
  begin
    FuncItem := TJclPeImportFuncItem.Create;
    FuncItem.FImportLib := Self;
    FuncItem.FResolveCheck := icNotChecked;
    if FThunk^.Ordinal and IMAGE_ORDINAL_FLAG <> 0 then
    begin
      FuncItem.FOrdinal := IMAGE_ORDINAL(FThunk^.Ordinal);
      FuncItem.FName := #0;
    end
    else
    begin
      case ImportKind of
        ikImport, ikBoundImport:
          OrdinalName := PImageImportByName(Image.RvaToVa(DWORD(FThunk^.AddressOfData)));
        ikDelayImport:
          OrdinalName := PImageImportByName(Image.RvaToVa(DWORD(FThunk^.AddressOfData - ImageBase)));
      else
        OrdinalName := nil;
      end;
      FuncItem.FHint := OrdinalName.Hint;
      FuncItem.FName := OrdinalName.Name;
    end;
    Add(FuncItem);
    Inc(FThunk);
  end;
  FThunk := nil;
end;

//------------------------------------------------------------------------------

function TJclPeImportLibItem.GetCount: Integer;
begin
  if FThunk <> nil then
    CreateList;
  Result := inherited Count;
end;

//------------------------------------------------------------------------------

function TJclPeImportLibItem.GetFileName: TFileName;
begin
  Result := FImage.ExpandModuleName(Name);
end;

//------------------------------------------------------------------------------

function TJclPeImportLibItem.GetItems(Index: Integer): TJclPeImportFuncItem;
begin
  Result := TJclPeImportFuncItem(inherited Items[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeImportLibItem.GetName: string;
begin
  Result := AnsiLowerCase(OriginalName);
end;

//------------------------------------------------------------------------------

function TJclPeImportLibItem.GetOriginalName: string;
begin
  Result := FName;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportLibItem.SortList(SortType: TJclPeImportSort; Descending: Boolean);
begin
  if not FSorted or (SortType <> FLastSortType) or (Descending <> FLastSortDescending) then
  begin
    GetCount; // create list if it wasn't created
    Sort(GetImportSortFunction(SortType, Descending));
    FLastSortType := SortType;
    FLastSortDescending := Descending;
    FSorted := True;
  end;
end;

//==============================================================================
// TJclPeImportList
//==============================================================================

procedure TJclPeImportList.CheckImports(PeImageCache: TJclPeImagesCache);
var
  I: Integer;
  ExportPeImage: TJclPeImage;
begin
  FImage.CheckNotAttached;
  if PeImageCache <> nil then
    ExportPeImage := nil // to make the compiler happy
  else
    ExportPeImage := TJclPeImage.Create(True);
  try
    for I := 0 to Count - 1 do
      if Items[I].TotalResolveCheck = icNotChecked then
      begin
        if PeImageCache <> nil then
          ExportPeImage := PeImageCache[Items[I].FileName]
        else
          ExportPeImage.FileName := Items[I].FileName;
        ExportPeImage.ExportList.PrepareForFastNameSearch;
        Items[I].CheckImports(ExportPeImage);
      end;
  finally
    if PeImageCache = nil then
      ExportPeImage.Free;
  end;
end;

//------------------------------------------------------------------------------

constructor TJclPeImportList.Create(AImage: TJclPeImage);
begin
  inherited Create(AImage);
  FAllItemsList := TList.Create;
  FAllItemsList.Capacity := 256;
  FUniqueNamesList := TStringList.Create;
  FUniqueNamesList.Sorted := True;
  FUniqueNamesList.Duplicates := dupIgnore;
  FLastAllSortType := isName;
  FLastAllSortDescending := False;
  CreateList;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.CreateList;
var
  ImportDesc: PImageImportDescriptor;
  LibItem: TJclPeImportLibItem;
  DelayImportDesc: PImgDelayDescr;
  ImageBase: DWORD;
  BoundImports, BoundImport: PImageBoundImportDescriptor;
  S: string;
  I: Integer;
begin
  SetCapacity(100);
  with Image do
  begin
    if not StatusOK then
      Exit;
    ImportDesc := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_IMPORT);
    if ImportDesc <> nil then
      while ImportDesc^.Name <> 0 do
      begin
        LibItem := TJclPeImportLibItem.Create(Image);
        LibItem.FImportDescriptor := ImportDesc;
        LibItem.FName := RvaToVa(ImportDesc^.Name);
        LibItem.FImportKind := ikImport;
        if ImportDesc^.Characteristics = 0 then
        begin
          if FAttachedImage then  // Borland images doesn't have two paralel arrays
            LibItem.FThunk := nil // see MakeBorlandImportTableForMappedImage method
          else
            LibItem.FThunk := PImageThunkData(RvaToVa(ImportDesc^.FirstThunk));
          FLinkerProducer := lrBorland;
        end
        else
        begin
          LibItem.FThunk := PImageThunkData(RvaToVa(ImportDesc^.Characteristics));
          FLinkerProducer := lrMicrosoft;
        end;
        LibItem.FThunkData := LibItem.FThunk;
        Add(LibItem);
        FUniqueNamesList.AddObject(AnsiLowerCase(LibItem.Name), LibItem);
        Inc(ImportDesc);
      end;
    DelayImportDesc := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT);
    if DelayImportDesc <> nil then
    begin
      ImageBase := OptionalHeader.ImageBase;
      while DelayImportDesc^.szName <> 0 do
      begin
        LibItem := TJclPeImportLibItem.Create(Image);
        LibItem.FImportKind := ikDelayImport;
        LibItem.FImportDescriptor := DelayImportDesc;
        LibItem.FName := RvaToVa(DelayImportDesc^.szName - ImageBase);
        LibItem.FThunk := PImageThunkData(RvaToVa(DelayImportDesc^.pINT.AddressOfData - ImageBase));
        Add(LibItem);
        FUniqueNamesList.AddObject(AnsiLowerCase(LibItem.Name), LibItem);
        Inc(DelayImportDesc);
      end;
    end;
    BoundImports := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT);
    if BoundImports <> nil then
    begin
      BoundImport := BoundImports;
      while BoundImport^.OffsetModuleName <> 0 do
      begin
        S := AnsiLowerCase(PChar(DWORD(BoundImports) + BoundImport^.OffsetModuleName));
        I := FUniqueNamesList.IndexOf(S);
        if I >= 0 then
          TJclPeImportLibItem(FUniqueNamesList.Objects[I]).FImportKind := ikBoundImport;
        for I := 1 to BoundImport^.NumberOfModuleForwarderRefs do
          Inc(PImageBoundForwarderRef(BoundImport)); // skip forward information
        Inc(BoundImport);
      end;
    end;
  end;
  for I := 0 to Count - 1 do
    Items[I].FImportDirectoryIndex := I;
end;

//------------------------------------------------------------------------------

destructor TJclPeImportList.Destroy;
var
  I: Integer;
begin
  FreeAndNil(FAllItemsList);
  FreeAndNil(FUniqueNamesList);
  for I := 0 to Length(FParalelImportTable) - 1 do
    FreeMem(FParalelImportTable[I]);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetAllItemCount: Integer;
begin
  Result := FAllItemsList.Count;
  if Result = 0 then // we haven't created the list yet -> create unsorted list
  begin
    RefreshAllItems;
    Result := FAllItemsList.Count;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetAllItems(Index: Integer): TJclPeImportFuncItem;
begin
  Result := TJclPeImportFuncItem(FAllItemsList[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetItems(Index: Integer): TJclPeImportLibItem;
begin
  Result := TJclPeImportLibItem(inherited Items[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetUniqueLibItemCount: Integer;
begin
  Result := FUniqueNamesList.Count;
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetUniqueLibItemFromName(const Name: string): TJclPeImportLibItem;
var
  I: Integer;
begin
  I := FUniqueNamesList.IndexOf(Name);
  if I = -1 then
    Result := nil
  else
    Result := TJclPeImportLibItem(FUniqueNamesList.Objects[I]);
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetUniqueLibItems(Index: Integer): TJclPeImportLibItem;
begin
  Result := TJclPeImportLibItem(FUniqueNamesList.Objects[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeImportList.GetUniqueLibNames(Index: Integer): string;
begin
  Result := FUniqueNamesList[Index];
end;

//------------------------------------------------------------------------------

function TJclPeImportList.MakeBorlandImportTableForMappedImage: Boolean;
var
  FileImage: TJclPeImage;
  I, TableSize: Integer;
begin
  if FImage.FAttachedImage and (FLinkerProducer = lrBorland) and
    (Length(FParalelImportTable) = 0) then
  begin
    FileImage := TJclPeImage.Create(True);
    try
      FileImage.FileName := FImage.FileName;
      Result := FileImage.StatusOK;
      if Result then
      begin
        SetLength(FParalelImportTable, FileImage.ImportList.Count);
        for I := 0 to FileImage.ImportList.Count - 1 do
        begin
          Assert(Items[I].ImportKind = ikImport); // Borland doesn't have Delay load or Bound imports
          TableSize := (FileImage.ImportList[I].Count + 1) * SizeOf(TImageThunkData);
          GetMem(FParalelImportTable[I], TableSize);
          System.Move(FileImage.ImportList[I].ThunkData^, FParalelImportTable[I]^, TableSize);
          Items[I].FThunk := FParalelImportTable[I];
        end;
      end;
    finally
      FileImage.Free;
    end;
  end else
    Result := True;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.RefreshAllItems;
var
  L, I: Integer;
  LibItem: TJclPeImportLibItem;
begin
  FAllItemsList.Clear;
  for L := 0 to Count - 1 do
  begin
    LibItem := Items[L];
    if (Length(FFilterModuleName) = 0) or (AnsiCompareText(LibItem.Name, FFilterModuleName) = 0) then
      for I := 0 to LibItem.Count - 1 do
        FAllItemsList.Add(LibItem[I]);
  end;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.SetFilterModuleName(const Value: string);
begin
  if (FFilterModuleName <> Value) or (FAllItemsList.Count = 0) then
  begin
    FFilterModuleName := Value;
    RefreshAllItems;
    FAllItemsList.Sort(GetImportSortFunction(FLastAllSortType, FLastAllSortDescending));
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImportList.SmartFindName(const CompareName, LibName: string;
  Options: TJclSmartCompOptions): TJclPeImportFuncItem;
var
  L, I: Integer;
  LibItem: TJclPeImportLibItem;
begin
  Result := nil;
  for L := 0 to Count - 1 do
  begin
    LibItem := Items[L];
    if (Length(LibName) = 0) or (AnsiCompareText(LibItem.Name, LibName) = 0) then
      for I := 0 to LibItem.Count - 1 do
        if PeSmartFunctionNameSame(CompareName, LibItem[I].Name, Options) then
        begin
          Result := LibItem[I];
          Break;
        end;
  end;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.SortAllItemsList(SortType: TJclPeImportSort; Descending: Boolean);
begin
  GetAllItemCount; // create list if it wasn't created
  FAllItemsList.Sort(GetImportSortFunction(SortType, Descending));
  FLastAllSortType := SortType;
  FLastAllSortDescending := Descending;
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.SortList(SortType: TJclPeImportLibSort);
begin
  Sort(GetImportLibSortFunction(SortType));
end;

//------------------------------------------------------------------------------

procedure TJclPeImportList.TryGetNamesForOrdinalImports;
var
  LibNamesList: TStringList;
  L, I: Integer;
  LibPeDump: TJclPeImage;

  procedure TryGetNames(const ModuleName: string);
  var
    Item: TJclPeImportFuncItem;
    I, L: Integer;
    ImportLibItem: TJclPeImportLibItem;
    ExportItem: TJclPeExportFuncItem;
    ExportList: TJclPeExportFuncList;
  begin
    if FImage.FAttachedImage then
      LibPeDump.AttachLoadedModule(GetModuleHandle(PChar(ModuleName)))
    else
      LibPeDump.FileName := FImage.ExpandModuleName(ModuleName);
    if not LibPeDump.StatusOK then
      Exit;
    ExportList := LibPeDump.ExportList;
    for L := 0 to Count - 1 do
    begin
      ImportLibItem := Items[L];
      if AnsiCompareText(ImportLibItem.Name, ModuleName) = 0 then
      begin
        for I := 0 to ImportLibItem.Count - 1 do
        begin
          Item := ImportLibItem[I];
          if Item.IsByOrdinal then
          begin
            ExportItem := ExportList.ItemFromOrdinal[Item.Ordinal];
            if (ExportItem <> nil) and (ExportItem.FName <> nil) then
              Item.SetIndirectImportName(ExportItem.FName);
          end;
        end;
        ImportLibItem.FSorted := False;
      end;
    end;
  end;

begin
  LibNamesList := TStringList.Create;
  try
    LibNamesList.Sorted := True;
    LibNamesList.Duplicates := dupIgnore;
    for L := 0 to Count - 1 do
      with Items[L] do
        for I := 0 to Count - 1 do
          if Items[I].IsByOrdinal then
            LibNamesList.Add(AnsiUpperCase(Name));
    LibPeDump := TJclPeImage.Create(True);
    try
      for I := 0 to LibNamesList.Count - 1 do
        TryGetNames(LibNamesList[I]);
    finally
      LibPeDump.Free;
    end;
    SortAllItemsList(FLastAllSortType, FLastAllSortDescending);
  finally
    LibNamesList.Free;
  end;
end;

//==============================================================================
// TJclPeExportFuncItem
//==============================================================================

procedure TJclPeExportFuncItem.FindForwardedDotPos;
begin
  if (FForwardedName <> nil) and (FForwardedDotPos = nil) then
    FForwardedDotPos := StrPos(FForwardedName, '.');
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetAddressOrForwardStr: string;
begin
  if IsForwarded then
    Result := ForwardedName
  else
    FmtStr(Result, '%.8x', [Address]);
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetForwardedFuncName: string;
begin
  FindForwardedDotPos;
  if (FForwardedDotPos <> nil) and (FForwardedDotPos + 1 <> '#') then
    Result := PChar(FForwardedDotPos + 1)
  else
    Result := '';
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetForwardedFuncOrdinal: DWORD;
begin
  FindForwardedDotPos;
  if (FForwardedDotPos <> nil) and (FForwardedDotPos + 1 = '#') then
    Result := StrToIntDef(FForwardedDotPos + 2, 0)
  else
    Result := 0;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetForwardedLibName: string;
begin
  FindForwardedDotPos;
  if FForwardedDotPos = nil then
    Result := ''
  else
  begin
    SetString(Result, FForwardedName, FForwardedDotPos - FForwardedName);
    Result := AnsiLowerCase(Result) + '.dll';
  end;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetForwardedName: string;
begin
  Result := FForwardedName;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetIsForwarded: Boolean;
begin
  Result := FForwardedName <> nil;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetMappedAddress: Pointer;
begin
  Result := FExportList.FImage.RvaToVa(FAddress);
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetName: string;
begin
  Result := FName;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncItem.GetSectionName: string;
begin
  if IsForwarded then
    Result := ''
  else
    with FExportList.FImage do
      Result := ImageSectionNameFromRva[Address];
end;

//==============================================================================
// Export sort functions
//==============================================================================

function ExportSortByName(Item1, Item2: Pointer): Integer;
begin
  Result := StrComp(TJclPeExportFuncItem(Item1).FName, TJclPeExportFuncItem(Item2).FName);
end;

function ExportSortByNameDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByName(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortByOrdinal(Item1, Item2: Pointer): Integer;
begin
  Result := TJclPeExportFuncItem(Item1).Ordinal - TJclPeExportFuncItem(Item2).Ordinal;
end;

function ExportSortByOrdinalDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByOrdinal(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortByHint(Item1, Item2: Pointer): Integer;
begin
  Result := TJclPeExportFuncItem(Item1).Hint - TJclPeExportFuncItem(Item2).Hint;
end;

function ExportSortByHintDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByHint(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortByAddress(Item1, Item2: Pointer): Integer;
begin
  Result := TJclPeExportFuncItem(Item1).Address - TJclPeExportFuncItem(Item2).Address;
  if Result = 0 then
    Result := ExportSortByName(Item1, Item2);
end;

function ExportSortByAddressDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByAddress(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortByForwarded(Item1, Item2: Pointer): Integer;
begin
  Result := CompareStr(TJclPeExportFuncItem(Item1).ForwardedName, TJclPeExportFuncItem(Item2).ForwardedName);
  if Result = 0 then
    Result := ExportSortByName(Item1, Item2);
end;

function ExportSortByForwardedDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByForwarded(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortByAddrOrFwd(Item1, Item2: Pointer): Integer;
begin
  Result := CompareStr(TJclPeExportFuncItem(Item1).AddressOrForwardStr, TJclPeExportFuncItem(Item2).AddressOrForwardStr);
end;

function ExportSortByAddrOrFwdDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortByAddrOrFwd(Item2, Item1);
end;

//------------------------------------------------------------------------------

function ExportSortBySection(Item1, Item2: Pointer): Integer;
begin
  Result := CompareStr(TJclPeExportFuncItem(Item1).SectionName, TJclPeExportFuncItem(Item2).SectionName);
  if Result = 0 then
    Result := ExportSortByName(Item1, Item2);
end;

function ExportSortBySectionDESC(Item1, Item2: Pointer): Integer;
begin
  Result := ExportSortBySection(Item2, Item1);
end;

//==============================================================================
// TJclPeExportFuncList
//==============================================================================

function TJclPeExportFuncList.CanPerformFastNameSearch: Boolean;
begin
  Result := FSorted and (FLastSortType = esName) and not FLastSortDescending;
end;

//------------------------------------------------------------------------------

procedure TJclPeExportFuncList.CheckForwards(PeImageCache: TJclPeImagesCache);
var
  I: Integer;
  FullFileName: TFileName;
  ForwardPeImage: TJclPeImage;
  ModuleResolveCheck: TJclPeResolveCheck;

  procedure PerformCheck(const ModuleName: string);
  var
    I: Integer;
    Item: TJclPeExportFuncItem;
    EL: TJclPeExportFuncList;
  begin
    EL := ForwardPeImage.ExportList;
    EL.PrepareForFastNameSearch;
    ModuleResolveCheck := icResolved;
    for I := 0 to Count - 1 do
    begin
      Item := Items[I];
      if (not Item.IsForwarded) or (Item.ResolveCheck <> icNotChecked) or
        (Item.ForwardedLibName <> ModuleName) then
        Continue;
      if EL.ItemFromName[Item.ForwardedFuncName] = nil then
      begin
        Item.FResolveCheck := icUnresolved;
        ModuleResolveCheck := icUnresolved;
      end
      else
        Item.FResolveCheck := icResolved;
    end;
  end;

begin
  if not AnyForwards then
    Exit;
  FTotalResolveCheck := icResolved;
  if PeImageCache <> nil then
    ForwardPeImage := nil // to make the compiler happy
  else
    ForwardPeImage := TJclPeImage.Create(True);
  try
    for I := 0 to ForwardedLibsList.Count - 1 do
    begin
      FullFileName := FImage.ExpandModuleName(ForwardedLibsList[I]);
      if PeImageCache <> nil then
        ForwardPeImage := PeImageCache[FullFileName]
      else
        ForwardPeImage.FileName := FullFileName;
      if ForwardPeImage.StatusOK then
        PerformCheck(ForwardedLibsList[I])
      else
        ModuleResolveCheck := icUnresolved;
      FForwardedLibsList.Objects[I] := Pointer(ModuleResolveCheck);
      if ModuleResolveCheck = icUnresolved then
        FTotalResolveCheck := icUnresolved;
    end;
  finally
    if PeImageCache = nil then
      ForwardPeImage.Free;
  end;
end;

//------------------------------------------------------------------------------

constructor TJclPeExportFuncList.Create(AImage: TJclPeImage);
begin
  inherited;
  FTotalResolveCheck := icNotChecked;
  CreateList;
end;

//------------------------------------------------------------------------------

procedure TJclPeExportFuncList.CreateList;
var
  Functions: DWORD;
  NameOrdinals: PWORD;
  Names: PDWORD;
  I: Integer;
  ExportItem: TJclPeExportFuncItem;
  ExportVABegin, ExportVAEnd: DWORD;
begin
  with FImage do
  begin
    if not StatusOK then
      Exit;
    with Directories[IMAGE_DIRECTORY_ENTRY_EXPORT] do
    begin
      ExportVABegin := VirtualAddress;
      ExportVAEnd := VirtualAddress + Size;
    end;
    FExportDir := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_EXPORT);
    if FExportDir <> nil then
    begin
      FBase := FExportDir^.Base;
      FFunctionCount := FExportDir^.NumberOfFunctions;
      Functions := DWORD(RvaToVa(DWORD(FExportDir^.AddressOfFunctions)));
      NameOrdinals := RvaToVa(DWORD(FExportDir^.AddressOfNameOrdinals));
      Names := RvaToVa(DWORD(FExportDir^.AddressOfNames));
      Count := FExportDir^.NumberOfNames;
      for I := 0 to FExportDir^.NumberOfNames - 1 do
      begin
        ExportItem := TJclPeExportFuncItem.Create;
        ExportItem.FExportList := Self;
        ExportItem.FOrdinal := NameOrdinals^ + FBase;
        ExportItem.FAddress := PDWORD(Functions + NameOrdinals^ * SizeOf(DWORD))^;
        ExportItem.FHint := I;
        ExportItem.FName := RvaToVa(DWORD(Names^));
        ExportItem.FResolveCheck := icNotChecked;
        if (ExportItem.FAddress >= ExportVABegin) and (ExportItem.FAddress <= ExportVAEnd) then
        begin
          FAnyForwards := True;
          ExportItem.FForwardedName := RvaToVa(ExportItem.FAddress);
        end
        else
          ExportItem.FForwardedName := nil;
        List^[I] := ExportItem; 
        Inc(NameOrdinals);
        Inc(Names);
      end;
    end;
  end;
end;

//------------------------------------------------------------------------------

destructor TJclPeExportFuncList.Destroy;
begin
  FreeAndNil(FForwardedLibsList);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetForwardedLibsList: TStrings;
var
  I: Integer;
begin
  if FForwardedLibsList = nil then
  begin
    FForwardedLibsList := TStringList.Create;
    FForwardedLibsList.Sorted := True;
    FForwardedLibsList.Duplicates := dupIgnore;
    if FAnyForwards then
      for I := 0 to Count - 1 do
        with Items[I] do
          if IsForwarded then
            FForwardedLibsList.AddObject(ForwardedLibName, Pointer(icNotChecked));
  end;
  Result := FForwardedLibsList;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetItemFromAddress(Address: DWORD): TJclPeExportFuncItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].Address = Address then
    begin
      Result := Items[I];
      Break;
    end;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetItemFromName(const Name: string): TJclPeExportFuncItem;
var
  L, H, I, C: Integer;
  B: Boolean;
begin
  Result := nil;
  if CanPerformFastNameSearch then
  begin
    L := 0;
    H := Count - 1;
    B := False;
    while L <= H do
    begin
      I := (L + H) shr 1;
      C := CompareStr(Items[I].Name, Name);
      if C < 0 then
        L := I + 1
      else
      begin
        H := I - 1;
        if C = 0 then
        begin
          B := True;
          L := I;
        end;
      end;
    end;
    if B then
      Result := Items[L];
  end
  else
    for I := 0 to Count - 1 do
      if Items[I].Name = Name then
      begin
        Result := Items[I];
        Break;
      end;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetItemFromOrdinal(Ordinal: DWORD): TJclPeExportFuncItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].Ordinal = Ordinal then
    begin
      Result := Items[I];
      Break;
    end;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetItems(Index: Integer): TJclPeExportFuncItem;
begin
  Result := TJclPeExportFuncItem(inherited Items[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.GetName: string;
begin
  if (FExportDir = nil) or (FExportDir^.Name = 0) then
    Result := ''
  else
    Result := PChar(Image.RvaToVa(FExportDir^.Name));
end;

//------------------------------------------------------------------------------

class function TJclPeExportFuncList.ItemName(Item: TJclPeExportFuncItem): string;
begin
  if Item = nil then
    Result := ''
  else
    Result := Item.Name;
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.OrdinalValid(Ordinal: DWORD): Boolean;
begin
  Result := (FExportDir <> nil) and (Ordinal >= Base) and
    (Ordinal < FunctionCount + Base);
end;

//------------------------------------------------------------------------------

procedure TJclPeExportFuncList.PrepareForFastNameSearch;
begin
  if not CanPerformFastNameSearch then
    SortList(esName, False);
end;

//------------------------------------------------------------------------------

function TJclPeExportFuncList.SmartFindName(const CompareName: string;
  Options: TJclSmartCompOptions): TJclPeExportFuncItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    if PeSmartFunctionNameSame(CompareName, Items[I].Name, Options) then
    begin
      Result := Items[I];
      Break;
    end;
  end;
end;

//------------------------------------------------------------------------------

procedure TJclPeExportFuncList.SortList(SortType: TJclPeExportSort; Descending: Boolean);
const
  SortFunctions: array [TJclPeExportSort, Boolean] of TListSortCompare =
    ((ExportSortByName, ExportSortByNameDESC),
     (ExportSortByOrdinal, ExportSortByOrdinalDESC),
     (ExportSortByHint, ExportSortByHintDESC),
     (ExportSortByAddress, ExportSortByAddressDESC),
     (ExportSortByForwarded, ExportSortByForwardedDESC),
     (ExportSortByAddrOrFwd, ExportSortByAddrOrFwdDESC),
     (ExportSortBySection, ExportSortBySectionDESC)
    );
begin
  if not FSorted or (SortType <> FLastSortType) or (Descending <> FLastSortDescending) then
  begin
    Sort(SortFunctions[SortType, Descending]);
    FLastSortType := SortType;
    FLastSortDescending := Descending;
    FSorted := True;
  end;
end;

//==============================================================================
// TJclPeResourceRawStream
//==============================================================================

constructor TJclPeResourceRawStream.Create(AResourceItem: TJclPeResourceItem);
begin
  Assert(not AResourceItem.IsDirectory);
  inherited Create;
  with AResourceItem do
    SetPointer(RawEntryData, DataEntry^.Size);
end;

//------------------------------------------------------------------------------

function TJclPeResourceRawStream.Write(const Buffer; Count: Integer): Longint;
begin
  raise EJclPeImageError.CreateResRec(@SCantWriteResourceStreamError);
end;

//==============================================================================
// TJclPeResourceItem
//==============================================================================

destructor TJclPeResourceItem.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetDataEntry: PImageResourceDataEntry;
begin
  if GetIsDirectory then
    Result := nil
  else
    Result := PImageResourceDataEntry(OffsetToRawData(FEntry^.OffsetToData));
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetIsDirectory: Boolean;
begin
  Result := FEntry^.OffsetToData and IMAGE_RESOURCE_DATA_IS_DIRECTORY <> 0;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetIsName: Boolean;
begin
  Result := FEntry^.Name and IMAGE_RESOURCE_NAME_IS_STRING <> 0;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetList: TJclPeResourceList;
begin
  if not IsDirectory then
  begin
    if FImage.FNoExceptions then
    begin
      Result := nil;
      Exit;
    end
    else
      raise EJclPeImageError.CreateResRec(@RsPeNotResDir);
  end;
  if FList = nil then
    FList := TJclPeResourceList.Create(SubDirData, FImage, Self);
  Result := FList;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetName: string;
begin
// TODO : Put name to local variable to increase the performance
  if IsName then
    with PImageResourceDirStringU(OffsetToRawData(FEntry^.Name))^ do
      Result := WideCharLenToString(NameString, Length) 
  else
    Result := IntToStr(FEntry^.Name and $FFFF);
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetParameterName: string;
begin
  if IsName then
    Result := Name
  else
    Result := Format('#%d', [FEntry^.Name and $FFFF]);
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetRawEntryData: Pointer;
begin
  if GetIsDirectory then
    Result := nil
  else
    Result := FImage.RvaToVa(GetDataEntry^.OffsetToData);
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetRawEntryDataSize: Integer;
begin
  if GetIsDirectory then
    Result := -1
  else
    Result := PImageResourceDataEntry(OffsetToRawData(FEntry^.OffsetToData))^.Size;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetResourceType: TJclResourceType;
begin
  with Level1Item do
  begin
    if FEntry^.Name <= 23 then
      Result := TJclResourceType(FEntry^.Name)
    else
      Result := rtUserDefined
  end;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.GetResourceTypeStr: string;
begin
  with Level1Item do
  begin
    if FEntry^.Name <= 23 then
      Result := Copy(GetEnumName(TypeInfo(TJclResourceType), Ord(FEntry^.Name)), 3, 30)
    else
      Result := Name;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.Level1Item: TJclPeResourceItem;
begin
  Result := Self;
  while Result.FParentItem <> nil do
    Result := Result.FParentItem;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.OffsetToRawData(Ofs: DWORD): DWORD;
begin
  Result := (Ofs and $7FFFFFFF) + FImage.FResourceVA;
end;

//------------------------------------------------------------------------------

function TJclPeResourceItem.SubDirData: PImageResourceDirectory;
begin
  Result := Pointer(OffsetToRawData(FEntry^.OffsetToData));
end;

//==============================================================================
// TJclPeResourceList
//==============================================================================

constructor TJclPeResourceList.Create(ADirectory: PImageResourceDirectory;
  AImage: TJclPeImage; AParentItem: TJclPeResourceItem);
begin
  inherited Create(AImage);
  FDirectory := ADirectory;
  CreateList(AParentItem);
end;

//------------------------------------------------------------------------------

procedure TJclPeResourceList.CreateList(AParentItem: TJclPeResourceItem);
var
  Entry: PImageResourceDirectoryEntry;
  DirItem: TJclPeResourceItem;
  I: Integer;
begin
  if FDirectory = nil then
    Exit;
  Entry := Pointer(DWORD(FDirectory) + SizeOf(TImageResourceDirectory));
  for I := 1 to FDirectory^.NumberOfNamedEntries + FDirectory^.NumberOfIdEntries do
  begin
    DirItem := TJclPeResourceItem.Create;
    DirItem.FEntry := Entry;
    DirItem.FImage := FImage;
    DirItem.FParentItem := AParentItem;
    Add(DirItem);
    Inc(Entry);
  end;
end;

//------------------------------------------------------------------------------

function TJclPeResourceList.GetItems(Index: Integer): TJclPeResourceItem;
begin
  Result := TJclPeResourceItem(inherited Items[Index]);
end;

//==============================================================================
// TJclPeRootResourceList
//==============================================================================

constructor TJclPeRootResourceList.Create(ADirectory: PImageResourceDirectory; AImage: TJclPeImage);
begin
  inherited Create(ADirectory, AImage, nil);
end;

//------------------------------------------------------------------------------

function TJclPeRootResourceList.FindResource(ResourceType: TJclResourceType;
  const ResourceName: string): TJclPeResourceItem;
var
  I: Integer;
  TypeItem: TJclPeResourceItem;
begin
  Result := nil;
  TypeItem := nil;
  for I := 0 to Count - 1 do
  begin
    if Items[I].ResourceType = ResourceType then
    begin
      TypeItem := Items[I];
      Break;
    end;
  end;
  if TypeItem <> nil then
  begin
    if ResourceName = '' then
      Result := TypeItem
    else
      with TypeItem.List do
        for I := 0 to Count - 1 do
          if Items[I].Name = ResourceName then
          begin
            Result := Items[I];
            Break;
          end;
  end;
end;

//==============================================================================
// TJclPeRelocEntry
//==============================================================================

function TJclPeRelocEntry.GetRelocations(Index: Integer): TJclPeRelocation;
var
  Temp: Word;
begin
  Temp := PWord(DWORD(FChunk) + SizeOf(TImageBaseRelocation) + DWORD(Index) * SizeOf(Word))^;
  Result.Address := Temp and $0FFF;
  Result.RelocType := (Temp and $F000) shr 12;
  Result.VirtualAddress := Result.Address + VirtualAddress; 
end;

//------------------------------------------------------------------------------

function TJclPeRelocEntry.GetSize: DWORD;
begin
  Result := FChunk^.SizeOfBlock;
end;

//------------------------------------------------------------------------------

function TJclPeRelocEntry.GetVirtualAddress: DWORD;
begin
  Result := FChunk^.VirtualAddress;
end;

//==============================================================================
// TJclPeRelocList
//==============================================================================

constructor TJclPeRelocList.Create(AImage: TJclPeImage);
begin
  inherited;
  CreateList;
end;

//------------------------------------------------------------------------------

procedure TJclPeRelocList.CreateList;
var
  Chunk: PImageBaseRelocation;
  Item: TJclPeRelocEntry;
begin
  with FImage do
  begin
    if not StatusOK then
      Exit;
    Chunk := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_BASERELOC);
    if Chunk = nil then
      Exit;
    FAllItemCount := 0;
    while Chunk^.SizeOfBlock <> 0 do
    begin
      Item := TJclPeRelocEntry.Create;
      Item.FChunk := Chunk;
      Item.FCount := (Chunk^.SizeOfBlock - SizeOf(TImageBaseRelocation)) div SizeOf(Word);
      Inc(FAllItemCount, Item.FCount);
      Add(Item);
      Chunk := Pointer(DWORD(Chunk) + Chunk^.SizeOfBlock);
    end;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeRelocList.GetAllItems(Index: Integer): TJclPeRelocation;
var
  I, N, C: Integer;
begin
  N := Index;
  for I := 0 to Count - 1 do
  begin
    C := Items[I].Count;
    Dec(N, C);
    if N < 0 then
    begin
      Result := Items[I][N + C];
      Break;
    end;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeRelocList.GetItems(Index: Integer): TJclPeRelocEntry;
begin
  Result := TJclPeRelocEntry(inherited Items[Index]);
end;

//==============================================================================
// TJclPeDebugList
//==============================================================================

constructor TJclPeDebugList.Create(AImage: TJclPeImage);
begin
  inherited;
  OwnsObjects := False;
  CreateList;
end;

//------------------------------------------------------------------------------

procedure TJclPeDebugList.CreateList;
var
  DebugImageDir: TImageDataDirectory;
  DebugDir: PImageDebugDirectory;
  Header: PImageSectionHeader;
  FormatCount, I: Integer;
begin
  with FImage do
  begin
    if not StatusOK then
      Exit;
    DebugImageDir := Directories[IMAGE_DIRECTORY_ENTRY_DEBUG];
    if DebugImageDir.VirtualAddress = 0 then
      Exit;
    if GetSectionHeader('.debug', Header) and
      (Header^.VirtualAddress = DebugImageDir.VirtualAddress) then
    begin
      FormatCount := DebugImageDir.Size;
      DebugDir := RvaToVa(Header^.VirtualAddress);
    end
    else
    begin
      if not GetSectionHeader('.rdata', Header) then
        Exit;
      FormatCount := DebugImageDir.Size div SizeOf(TImageDebugDirectory);
      DebugDir := Pointer(MappedAddress + DebugImageDir.VirtualAddress -
        Header^.VirtualAddress + Header^.PointerToRawData);
    end;
    for I := 1 to FormatCount do
    begin
      Add(TObject(DebugDir));
      Inc(DebugDir);
    end;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeDebugList.GetItems(Index: Integer): TImageDebugDirectory;
begin
  Result := PImageDebugDirectory(inherited Items[Index])^;
end;

//==============================================================================
// TJclPeImage
//==============================================================================

procedure TJclPeImage.AfterOpen;
begin
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.AttachLoadedModule(const Handle: HMODULE);
var
  NtHeaders: PImageNtHeaders;
begin
  Clear;
  if Handle = 0 then
    Exit;
  NtHeaders := PeMapImgNtHeaders(Pointer(Handle));
  if NtHeaders = nil then
    FStatus := stNotPE
  else
  begin
    FStatus := stOk;
    FAttachedImage := True;
    FFileName := GetModulePath(Handle);
    FLoadedImage.ModuleName := PChar(FFileName);
    FLoadedImage.hFile := INVALID_HANDLE_VALUE;
    FLoadedImage.MappedAddress := Pointer(Handle);
    FLoadedImage.FileHeader := NtHeaders;
    FLoadedImage.NumberOfSections := NtHeaders^.FileHeader.NumberOfSections;
    FLoadedImage.Sections := PeMapImgSections(NtHeaders);
    FLoadedImage.LastRvaSection := FLoadedImage.Sections;
    FLoadedImage.Characteristics := NtHeaders^.FileHeader.Characteristics;
    FLoadedImage.fSystemImage := (FLoadedImage.Characteristics and IMAGE_FILE_SYSTEM <> 0);
    FLoadedImage.fDOSImage := False;
    FLoadedImage.SizeOfImage := NtHeaders^.OptionalHeader.SizeOfImage;
    ReadImageSections;
    AfterOpen;
  end;
  RaiseStatusException;
end;

//------------------------------------------------------------------------------

function TJclPeImage.CalculateCheckSum: DWORD;
var
  C: DWORD;
begin
  if StatusOK then
  begin
    CheckNotAttached;
    if CheckSumMappedFile(FLoadedImage.MappedAddress, FLoadedImage.SizeOfImage,
      @C, @Result) = nil then
        RaiseLastWin32Error;
  end
  else
    Result := 0;
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.CheckNotAttached;
begin
  if FAttachedImage then
    raise EJclPeImageError.CreateResRec(@RsPeNotAvailableForAttached);
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.Clear;
begin
  FImageSections.Clear;
  FreeAndNil(FDebugList);
  FreeAndNil(FImportList);
  FreeAndNil(FExportList);
  FreeAndNil(FRelocationList);
  FreeAndNil(FResourceList);
  FreeAndNil(FVersionInfo);
  if not FAttachedImage and StatusOK then
    UnMapAndLoad(@FLoadedImage);
  FillChar(FLoadedImage, SizeOf(FLoadedImage), #0);
  FStatus := stNotLoaded;
  FAttachedImage := False;
end;

//------------------------------------------------------------------------------

constructor TJclPeImage.Create(ANoExceptions: Boolean);
begin
  FNoExceptions := ANoExceptions;
  FReadOnlyAccess := True;
  FImageSections := TStringList.Create;
end;

//------------------------------------------------------------------------------

class function TJclPeImage.DebugTypeNames(DebugType: DWORD): string;
begin
  case DebugType of
    IMAGE_DEBUG_TYPE_UNKNOWN:
      Result := RsPeDEBUG_UNKNOWN;
    IMAGE_DEBUG_TYPE_COFF:
      Result := RsPeDEBUG_COFF;
    IMAGE_DEBUG_TYPE_CODEVIEW:
      Result := RsPeDEBUG_CODEVIEW;
    IMAGE_DEBUG_TYPE_FPO:
      Result := RsPeDEBUG_FPO;
    IMAGE_DEBUG_TYPE_MISC:
      Result := RsPeDEBUG_MISC;
    IMAGE_DEBUG_TYPE_EXCEPTION:
      Result := RsPeDEBUG_EXCEPTION;
    IMAGE_DEBUG_TYPE_FIXUP:
      Result := RsPeDEBUG_FIXUP;
    IMAGE_DEBUG_TYPE_OMAP_TO_SRC:
      Result := RsPeDEBUG_OMAP_TO_SRC;
    IMAGE_DEBUG_TYPE_OMAP_FROM_SRC:
      Result := RsPeDEBUG_OMAP_FROM_SRC;
  else
    Result := '???';
  end;  
end;

//------------------------------------------------------------------------------

destructor TJclPeImage.Destroy;
begin
  Clear;
  FreeAndNil(FImageSections);
  inherited Destroy;
end;

//------------------------------------------------------------------------------

function TJclPeImage.DirectoryEntryToData(Directory: Word): Pointer;
var
  Size: DWORD;
begin
  Result := ImageDirectoryEntryToData(FLoadedImage.MappedAddress, FAttachedImage, Directory, Size);
end;

//------------------------------------------------------------------------------

class function TJclPeImage.DirectoryNames(Directory: Word): string;
begin
  case Directory of
    IMAGE_DIRECTORY_ENTRY_EXPORT:
      Result := RsPeImg_00;
    IMAGE_DIRECTORY_ENTRY_IMPORT:
      Result := RsPeImg_01;
    IMAGE_DIRECTORY_ENTRY_RESOURCE:
      Result := RsPeImg_02;
    IMAGE_DIRECTORY_ENTRY_EXCEPTION:
      Result := RsPeImg_03;
    IMAGE_DIRECTORY_ENTRY_SECURITY:
      Result := RsPeImg_04;
    IMAGE_DIRECTORY_ENTRY_BASERELOC:
      Result := RsPeImg_05;
    IMAGE_DIRECTORY_ENTRY_DEBUG:
      Result := RsPeImg_06;
    IMAGE_DIRECTORY_ENTRY_COPYRIGHT:
      Result := RsPeImg_07;
    IMAGE_DIRECTORY_ENTRY_GLOBALPTR:
      Result := RsPeImg_08;
    IMAGE_DIRECTORY_ENTRY_TLS:
      Result := RsPeImg_09;
    IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG:
      Result := RsPeImg_10;
    IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT:
      Result := RsPeImg_11;
    IMAGE_DIRECTORY_ENTRY_IAT:
      Result := RsPeImg_12;
    IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT:
      Result := RsPeImg_13;
    IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR:
      Result := RsPeImg_14;
  else
    Result := Format('reserved [%.2d]', [Directory]);
  end;
end;

//------------------------------------------------------------------------------

class function TJclPeImage.ExpandBySearchPath(const ModuleName, BasePath: string): TFileName;
var
  FullName: array [0..MAX_PATH] of Char;
  FilePart: PChar;
begin
  Result := PathAddSeparator(ExtractFilePath(BasePath)) + ModuleName;
  if FileExists(Result) then
    Exit;
  if SearchPath(nil, PChar(ModuleName), nil, SizeOf(FullName), FullName, FilePart) = 0 then
    Result := ModuleName
  else
    Result := FullName;
end;

//------------------------------------------------------------------------------

function TJclPeImage.ExpandModuleName(const ModuleName: string): TFileName;
begin
  Result := ExpandBySearchPath(ModuleName, ExtractFilePath(FFileName));
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetDebugList: TJclPeDebugList;
begin
  if FDebugList = nil then
    FDebugList := TJclPeDebugList.Create(Self);
  Result := FDebugList; 
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetDescription: string;
begin
  if DirectoryExists[IMAGE_DIRECTORY_ENTRY_COPYRIGHT] then
    Result := PChar(DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_COPYRIGHT))
  else
    Result := '';
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetDirectories(Directory: Word): TImageDataDirectory;
begin
  Result := FLoadedImage.FileHeader.OptionalHeader.DataDirectory[Directory];
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetDirectoryExists(Directory: Word): Boolean;
begin
  Result := StatusOK and (Directories[Directory].VirtualAddress <> 0);
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetExportList: TJclPeExportFuncList;
begin
  if FExportList = nil then
    FExportList := TJclPeExportFuncList.Create(Self);
  Result := FExportList;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetFileProperties: TJclPeFileProperties;
const
  faFile = faReadOnly or faHidden or faSysFile or faArchive;
var
  Se: TSearchRec;
  Res: Integer;
begin
  FillChar(Result, SizeOf(Result), #0);
  Res := FindFirst(FileName, faFile, Se);
  if Res = 0 then
  begin
    Result.Size := Se.Size;
    Result.CreationTime := FileTimeToLocalDateTime(Se.FindData.ftCreationTime);
    Result.LastAccessTime := FileTimeToLocalDateTime(Se.FindData.ftLastAccessTime);
    Result.LastWriteTime := FileTimeToLocalDateTime(Se.FindData.ftLastWriteTime);
    Result.Attributes := Se.Attr;
  end;
  FindClose(Se);
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetHeaderValues(Index: TJclPeHeader): string;

  function GetMachineString(Value: DWORD): string;
  begin
    case Value of
      IMAGE_FILE_MACHINE_UNKNOWN:
        Result := RsPeMACHINE_UNKNOWN;
      IMAGE_FILE_MACHINE_I386:
        Result := RsPeMACHINE_I386;
      IMAGE_FILE_MACHINE_R3000:
        Result := RsPeMACHINE_R3000;
      IMAGE_FILE_MACHINE_R4000:
        Result := RsPeMACHINE_R4000;
      IMAGE_FILE_MACHINE_R10000:
        Result := RsPeMACHINE_R10000;
      IMAGE_FILE_MACHINE_ALPHA:
        Result := RsPeMACHINE_ALPHA;
      IMAGE_FILE_MACHINE_POWERPC:
        Result := RsPeMACHINE_POWERPC;
    else
      Result := Format('[%.8x]', [Value]);
    end;
  end;

  function GetSubsystemString(Value: DWORD): string;
  begin
    case Value of
      IMAGE_SUBSYSTEM_UNKNOWN:
        Result := RsPeSUBSYSTEM_UNKNOWN;
      IMAGE_SUBSYSTEM_NATIVE:
        Result := RsPeSUBSYSTEM_NATIVE;
      IMAGE_SUBSYSTEM_WINDOWS_GUI:
        Result := RsPeSUBSYSTEM_WINDOWS_GUI;
      IMAGE_SUBSYSTEM_WINDOWS_CUI:
        Result := RsPeSUBSYSTEM_WINDOWS_CUI;
      IMAGE_SUBSYSTEM_OS2_CUI:
        Result := RsPeSUBSYSTEM_OS2_CUI;
      IMAGE_SUBSYSTEM_POSIX_CUI:
        Result := RsPeSUBSYSTEM_POSIX_CUI;
      IMAGE_SUBSYSTEM_RESERVED8:
        Result := RsPeSUBSYSTEM_RESERVED8;
    else
      Result := Format('[%.8x]', [Value]);
    end;
  end;

begin
  if StatusOK then
    with FLoadedImage.FileHeader^ do
      case Index of
        JclPeHeader_Signature:
          Result := IntToHex(Signature, 8);
        JclPeHeader_Machine:
          Result := GetMachineString(FileHeader.Machine);
        JclPeHeader_NumberOfSections:
          Result := IntToHex(FileHeader.NumberOfSections, 4);
        JclPeHeader_TimeDateStamp:
          Result := IntToHex(FileHeader.TimeDateStamp, 8);
        JclPeHeader_PointerToSymbolTable:
          Result := IntToHex(FileHeader.PointerToSymbolTable, 8);
        JclPeHeader_NumberOfSymbols:
          Result := IntToHex(FileHeader.NumberOfSymbols, 8);
        JclPeHeader_SizeOfOptionalHeader:
          Result := IntToHex(FileHeader.SizeOfOptionalHeader, 4);
        JclPeHeader_Characteristics:
          Result := IntToHex(FileHeader.Characteristics, 4);
        JclPeHeader_Magic:
          Result := IntToHex(OptionalHeader.Magic, 4);
        JclPeHeader_LinkerVersion:
          Result := GetVersionString(OptionalHeader.MajorLinkerVersion, OptionalHeader.MinorLinkerVersion);
        JclPeHeader_SizeOfCode:
          Result := IntToHex(OptionalHeader.SizeOfCode, 8);
        JclPeHeader_SizeOfInitializedData:
          Result := IntToHex(OptionalHeader.SizeOfInitializedData, 8);
        JclPeHeader_SizeOfUninitializedData:
          Result := IntToHex(OptionalHeader.SizeOfUninitializedData, 8);
        JclPeHeader_AddressOfEntryPoint:
          Result := IntToHex(OptionalHeader.AddressOfEntryPoint, 8);
        JclPeHeader_BaseOfCode:
          Result := IntToHex(OptionalHeader.BaseOfCode, 8);
        JclPeHeader_BaseOfData:
          Result := IntToHex(OptionalHeader.BaseOfData, 8);
        JclPeHeader_ImageBase:
          Result := IntToHex(OptionalHeader.ImageBase, 8);
        JclPeHeader_SectionAlignment:
          Result := IntToHex(OptionalHeader.SectionAlignment, 8);
        JclPeHeader_FileAlignment:
          Result := IntToHex(OptionalHeader.FileAlignment, 8);
        JclPeHeader_OperatingSystemVersion:
          Result := GetVersionString(OptionalHeader.MajorOperatingSystemVersion, OptionalHeader.MinorOperatingSystemVersion);
        JclPeHeader_ImageVersion:
          Result := GetVersionString(OptionalHeader.MajorImageVersion, OptionalHeader.MinorImageVersion);
        JclPeHeader_SubsystemVersion:
          Result := GetVersionString(OptionalHeader.MajorSubsystemVersion, OptionalHeader.MinorSubsystemVersion);
        JclPeHeader_Win32VersionValue:
          Result := IntToHex(OptionalHeader.Win32VersionValue, 8);
        JclPeHeader_SizeOfImage:
          Result := IntToHex(OptionalHeader.SizeOfImage, 8);
        JclPeHeader_SizeOfHeaders:
          Result := IntToHex(OptionalHeader.SizeOfHeaders, 8);
        JclPeHeader_CheckSum:
          Result := IntToHex(OptionalHeader.CheckSum, 8);
        JclPeHeader_Subsystem:
          Result := GetSubsystemString(OptionalHeader.Subsystem);
        JclPeHeader_DllCharacteristics:
          Result := IntToHex(OptionalHeader.DllCharacteristics, 4);
        JclPeHeader_SizeOfStackReserve:
          Result := IntToHex(OptionalHeader.SizeOfStackReserve, 8);
        JclPeHeader_SizeOfStackCommit:
          Result := IntToHex(OptionalHeader.SizeOfStackCommit, 8);
        JclPeHeader_SizeOfHeapReserve:
          Result := IntToHex(OptionalHeader.SizeOfHeapReserve, 8);
        JclPeHeader_SizeOfHeapCommit:
          Result := IntToHex(OptionalHeader.SizeOfHeapCommit, 8);
        JclPeHeader_LoaderFlags:
          Result := IntToHex(OptionalHeader.LoaderFlags, 8);
        JclPeHeader_NumberOfRvaAndSizes:
          Result := IntToHex(OptionalHeader.NumberOfRvaAndSizes, 8);
      else
        Result := '';
      end
  else
    Result := '';
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetImageSectionCount: Integer;
begin
  Result := FImageSections.Count;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetImageSectionHeaders(Index: Integer): TImageSectionHeader;
begin
  Result := PImageSectionHeader(FImageSections.Objects[Index])^;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetImageSectionNameFromRva(const Rva: DWORD): string;
begin
  Result := GetSectionName(RvaToSection(Rva));
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetImageSectionNames(Index: Integer): string;
begin
  Result := FImageSections[Index];
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetImportList: TJclPeImportList;
begin
  if FImportList = nil then
    FImportList := TJclPeImportList.Create(Self);
  Result := FImportList;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetLoadConfigValues(Index: TJclLoadConfig): string;
var
  LoadConfig: PImageLoadConfigDirectory;
begin
  Result := '';
  LoadConfig := DirectoryEntryToData(IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG);
  if LoadConfig <> nil then
    with LoadConfig^ do
      case Index of
        JclLoadConfig_Characteristics:
          Result := IntToHex(Characteristics, 8);
        JclLoadConfig_TimeDateStamp:
          Result := IntToHex(TimeDateStamp, 8);
        JclLoadConfig_Version:
          Result := GetVersionString(MajorVersion, MinorVersion);
        JclLoadConfig_GlobalFlagsClear:
          Result := IntToHex(GlobalFlagsClear, 8);
        JclLoadConfig_GlobalFlagsSet:
          Result := IntToHex(GlobalFlagsSet, 8);
        JclLoadConfig_CriticalSectionDefaultTimeout:
          Result := IntToHex(CriticalSectionDefaultTimeout, 8);
        JclLoadConfig_DeCommitFreeBlockThreshold:
          Result := IntToHex(DeCommitFreeBlockThreshold, 8);
        JclLoadConfig_DeCommitTotalFreeThreshold:
          Result := IntToHex(DeCommitTotalFreeThreshold, 8);
        JclLoadConfig_LockPrefixTable:
          Result := IntToHex(LockPrefixTable, 8);
        JclLoadConfig_MaximumAllocationSize:
          Result := IntToHex(MaximumAllocationSize, 8);
        JclLoadConfig_VirtualMemoryThreshold:
          Result := IntToHex(VirtualMemoryThreshold, 8);
        JclLoadConfig_ProcessHeapFlags:
          Result := IntToHex(ProcessHeapFlags, 8);
        JclLoadConfig_ProcessAffinityMask:
          Result := IntToHex(ProcessAffinityMask, 8);
        JclLoadConfig_CSDVersion:
          Result := IntToHex(CSDVersion, 4);
        JclLoadConfig_Reserved1:
          Result := IntToHex(Reserved1, 4);
        JclLoadConfig_EditList:
          Result := IntToHex(EditList, 8);
        JclLoadConfig_Reserved:
          Result := RsPeReserved;
      end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetMappedAddress: DWORD;
begin
  if StatusOK then
    Result := DWORD(LoadedImage.MappedAddress)
  else
    Result := 0;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetOptionalHeader: TImageOptionalHeader;
begin
  Result := FLoadedImage.FileHeader.OptionalHeader;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetRelocationList: TJclPeRelocList;
begin
  if FRelocationList = nil then
    FRelocationList := TJclPeRelocList.Create(Self);
  Result := FRelocationList;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetResourceList: TJclPeRootResourceList;
begin
  if FResourceList = nil then
  begin
    FResourceVA := Directories[IMAGE_DIRECTORY_ENTRY_RESOURCE].VirtualAddress;
    if FResourceVA <> 0 then
      FResourceVA := DWORD(RvaToVa(FResourceVA));
    FResourceList := TJclPeRootResourceList.Create(Pointer(FResourceVA), Self);
  end;
  Result := FResourceList;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetSectionHeader(const SectionName: string;
  var Header: PImageSectionHeader): Boolean;
var
  I: Integer;
begin
  I := FImageSections.IndexOf(SectionName);
  if I = -1 then
  begin
    Header := nil;
    Result := False;
  end
  else
  begin
    Header := PImageSectionHeader(FImageSections.Objects[I]);
    Result := True;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetSectionName(const Header: PImageSectionHeader): string;
var
  I: Integer;
begin
  I := FImageSections.IndexOfObject(TObject(Header));
  if I = -1 then
    Result := ''
  else
    Result := FImageSections[I];
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetUnusedHeaderBytes: TImageDataDirectory;
begin
  CheckNotAttached;
  Result.VirtualAddress := GetImageUnusedHeaderBytes(@FLoadedImage, Result.Size);
  if Result.VirtualAddress = 0 then
    RaiseLastWin32Error;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetVersionInfo: TJclFileVersionInfo;
var
  VersionInfoResource: TJclPeResourceItem;
begin
  if (FVersionInfo = nil) and VersionInfoAvailable then
  begin
    VersionInfoResource := ResourceList.FindResource(rtVersion, '1').List[0];
    with VersionInfoResource do
      try
        FVersionInfo := TJclFileVersionInfo.Attach(RawEntryData, RawEntryDataSize);
      except
        FreeAndNil(FVersionInfo);
      end;  
  end;
  Result := FVersionInfo;
end;

//------------------------------------------------------------------------------

function TJclPeImage.GetVersionInfoAvailable: Boolean;
begin
  Result := StatusOK and (ResourceList.FindResource(rtVersion, '1') <> nil);
end;

//------------------------------------------------------------------------------

class function TJclPeImage.HeaderNames(Index: TJclPeHeader): string;
begin
  case Index of
    JclPeHeader_Signature:
      Result := RsPeSignature;
    JclPeHeader_Machine:
      Result := RsPeMachine;
    JclPeHeader_NumberOfSections:
      Result := RsPeNumberOfSections;
    JclPeHeader_TimeDateStamp:
      Result := RsPeTimeDateStamp;
    JclPeHeader_PointerToSymbolTable:
      Result := RsPePointerToSymbolTable;
    JclPeHeader_NumberOfSymbols:
      Result := RsPeNumberOfSymbols;
    JclPeHeader_SizeOfOptionalHeader:
      Result := RsPeSizeOfOptionalHeader;
    JclPeHeader_Characteristics:
      Result := RsPeCharacteristics;
    JclPeHeader_Magic:
      Result := RsPeMagic;
    JclPeHeader_LinkerVersion:
      Result := RsPeLinkerVersion;
    JclPeHeader_SizeOfCode:
      Result := RsPeSizeOfCode;
    JclPeHeader_SizeOfInitializedData:
      Result := RsPeSizeOfInitializedData;
    JclPeHeader_SizeOfUninitializedData:
      Result := RsPeSizeOfUninitializedData;
    JclPeHeader_AddressOfEntryPoint:
      Result := RsPeAddressOfEntryPoint;
    JclPeHeader_BaseOfCode:
      Result := RsPeBaseOfCode;
    JclPeHeader_BaseOfData:
      Result := RsPeBaseOfData;
    JclPeHeader_ImageBase:
      Result := RsPeImageBase;
    JclPeHeader_SectionAlignment:
      Result := RsPeSectionAlignment;
    JclPeHeader_FileAlignment:
      Result := RsPeFileAlignment;
    JclPeHeader_OperatingSystemVersion:
      Result := RsPeOperatingSystemVersion;
    JclPeHeader_ImageVersion:
      Result := RsPeImageVersion;
    JclPeHeader_SubsystemVersion:
      Result := RsPeSubsystemVersion;
    JclPeHeader_Win32VersionValue:
      Result := RsPeWin32VersionValue;
    JclPeHeader_SizeOfImage:
      Result := RsPeSizeOfImage;
    JclPeHeader_SizeOfHeaders:
      Result := RsPeSizeOfHeaders;
    JclPeHeader_CheckSum:
      Result := RsPeCheckSum;
    JclPeHeader_Subsystem:
      Result := RsPeSubsystem;
    JclPeHeader_DllCharacteristics:
      Result := RsPeDllCharacteristics;
    JclPeHeader_SizeOfStackReserve:
      Result := RsPeSizeOfStackReserve;
    JclPeHeader_SizeOfStackCommit:
      Result := RsPeSizeOfStackCommit;
    JclPeHeader_SizeOfHeapReserve:
      Result := RsPeSizeOfHeapReserve;
    JclPeHeader_SizeOfHeapCommit:
      Result := RsPeSizeOfHeapCommit;
    JclPeHeader_LoaderFlags:
      Result := RsPeLoaderFlags;
    JclPeHeader_NumberOfRvaAndSizes:
      Result := RsPeNumberOfRvaAndSizes;
  else
    Result := '';
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.IsSystemImage: Boolean;
begin
  Result := StatusOK and FLoadedImage.fSystemImage;
end;

//------------------------------------------------------------------------------

class function TJclPeImage.LoadConfigNames(Index: TJclLoadConfig): string;
begin
  case Index of
    JclLoadConfig_Characteristics:
      Result := RsPeCharacteristics;
    JclLoadConfig_TimeDateStamp:
      Result := RsPeTimeDateStamp;
    JclLoadConfig_Version:
      Result := RsPeVersion;
    JclLoadConfig_GlobalFlagsClear:
      Result := RsPeGlobalFlagsClear;
    JclLoadConfig_GlobalFlagsSet:
      Result := RsPeGlobalFlagsSet;
    JclLoadConfig_CriticalSectionDefaultTimeout:
      Result := RsPeCriticalSectionDefaultTimeout;
    JclLoadConfig_DeCommitFreeBlockThreshold:
      Result := RsPeDeCommitFreeBlockThreshold;
    JclLoadConfig_DeCommitTotalFreeThreshold:
      Result := RsPeDeCommitTotalFreeThreshold;
    JclLoadConfig_LockPrefixTable:
      Result := RsPeLockPrefixTable;
    JclLoadConfig_MaximumAllocationSize:
      Result := RsPeMaximumAllocationSize;
    JclLoadConfig_VirtualMemoryThreshold:
      Result := RsPeVirtualMemoryThreshold;
    JclLoadConfig_ProcessHeapFlags:
      Result := RsPeProcessHeapFlags;
    JclLoadConfig_ProcessAffinityMask:
      Result := RsPeProcessAffinityMask;
    JclLoadConfig_CSDVersion:
      Result := RsPeCSDVersion;
    JclLoadConfig_Reserved1:
      Result := RsPeReserved;
    JclLoadConfig_EditList:
      Result := RsPeEditList;
    JclLoadConfig_Reserved:
      Result := RsPeReserved;
  else
    Result := '';
  end;    
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.RaiseStatusException;
begin
  if not FNoExceptions then
    case FStatus of
      stNotPE:
        raise EJclPeImageError.CreateResRec(@RsPeNotPE);
      stNotFound:
        raise EJclPeImageError.CreateResRecFmt(@RsPeCantOpen, [FFileName]);
      stError:
        RaiseLastWin32Error;
    end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.RawToVa(Raw: DWORD): Pointer;
begin
  Result := Pointer(DWORD(FLoadedImage.MappedAddress) + Raw);
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.ReadImageSections;
var
  I: Integer;
  Header: PImageSectionHeader;
begin
  if not StatusOK then
    Exit;
  Header := FLoadedImage.Sections;
  for I := 0 to FLoadedImage.NumberOfSections - 1 do
  begin
    FImageSections.AddObject(Copy(PChar(@Header.Name), 1, 8), Pointer(Header));
    Inc(Header);
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.RvaToSection(Rva: DWORD): PImageSectionHeader;
var
  I: Integer;
  SectionHeader: PImageSectionHeader;
  EndRVA: DWORD;
begin
{ TODO -cTEST : Test on NT system whether ImageRvaToSection is allowed without previous MapAndLoad call }
  Result := ImageRvaToSection(FLoadedImage.FileHeader, FLoadedImage.MappedAddress, Rva);
  if Result = nil then 
    for I := 0 to FImageSections.Count - 1 do
    begin
      SectionHeader := PImageSectionHeader(FImageSections.Objects[I]);
      if SectionHeader^.SizeOfRawData = 0 then
        EndRVA := SectionHeader^.Misc.VirtualSize
      else
        EndRVA := SectionHeader^.SizeOfRawData;
      Inc(EndRVA, SectionHeader^.VirtualAddress);
      if (SectionHeader^.VirtualAddress <= Rva) and (EndRVA >= Rva) then
      begin
        Result := SectionHeader;
        Break;
      end;
    end;      
end;

//------------------------------------------------------------------------------

function TJclPeImage.RvaToVa(Rva: DWORD): Pointer;
begin
  if FAttachedImage then
    Result := FLoadedImage.MappedAddress + Rva
  else
    Result := ImageRvaToVa(FLoadedImage.FileHeader, FLoadedImage.MappedAddress, Rva, nil);
end;

//------------------------------------------------------------------------------

procedure TJclPeImage.SetFileName(const Value: TFileName);
begin
  if FFileName <> Value then
  begin
    Clear;
    FFileName := Value;
    if FFileName = '' then
      Exit;
    if MapAndLoad(PChar(FFileName), nil, @FLoadedImage, True, FReadOnlyAccess) then
    begin
      FStatus := stOk;
      ReadImageSections;
      AfterOpen;
    end
    else
      case GetLastError of
        ERROR_SUCCESS:
          FStatus := stNotPE;
        ERROR_FILE_NOT_FOUND:
          FStatus := stNotFound;
      else
        FStatus := stError;
      end;
    RaiseStatusException;
  end;
end;

//------------------------------------------------------------------------------

class function TJclPeImage.ShortSectionInfo(Characteristics: DWORD): string;
type
  TSectionCharacteristics = record
    Mask: DWORD;
    InfoChar: Char;
  end;
const
  Info: array [1..7] of TSectionCharacteristics = (
    (Mask: IMAGE_SCN_CNT_CODE; InfoChar: 'C'),
    (Mask: IMAGE_SCN_CNT_INITIALIZED_DATA; InfoChar: 'I'),
    (Mask: IMAGE_SCN_CNT_UNINITIALIZED_DATA; InfoChar: 'U'),
    (Mask: IMAGE_SCN_MEM_SHARED; InfoChar: 'S'),
    (Mask: IMAGE_SCN_MEM_EXECUTE; InfoChar: 'E'),
    (Mask: IMAGE_SCN_MEM_READ; InfoChar: 'R'),
    (Mask: IMAGE_SCN_MEM_WRITE; InfoChar: 'W')
  );
var
  I: Integer;
begin
  SetLength(Result, High(Info));
  Result := '';
  for I := Low(Info) to High(Info) do
    with Info[I] do
      if (Characteristics and Mask) = Mask then
        Result := Result + InfoChar;
end;

//------------------------------------------------------------------------------

function TJclPeImage.StatusOK: Boolean;
begin
  Result := (FStatus = stOk);
end;

//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_INT64}
class function TJclPeImage.StampToDateTime(TimeDateStamp: DWORD): TDateTime;
var
  ST: TSystemTime;
  FT: Int64;
begin
  if TimeDateStamp = 0 then
    Result := 0
  else
  begin
    FillChar(ST, SizeOf(ST), #0);
    ST.wYear := 1970;
    ST.wMonth := 1;
    ST.wDay := 1;
    Windows.SystemTimeToFileTime(ST, TFileTime(FT));
    FT := FT + Int64(TimeDateStamp) * 10000000;
    Result := FileTimeToDateTime(TFileTime(FT));
  end;
end;
{$ENDIF SUPPORTS_INT64}

//------------------------------------------------------------------------------

procedure TJclPeImage.TryGetNamesForOrdinalImports;
begin
  if StatusOK then
  begin
    GetImportList;
    FImportList.TryGetNamesForOrdinalImports;
  end;
end;

//------------------------------------------------------------------------------

function TJclPeImage.VerifyCheckSum: Boolean;
begin
  CheckNotAttached;
  with OptionalHeader do
    Result := StatusOK and ((CheckSum = 0) or (CalculateCheckSum = CheckSum));
end;

//==============================================================================
// TJclPePackageInfo
//==============================================================================

constructor TJclPePackageInfo.Create(ALibHandle: THandle);
begin
  FContains := TStringList.Create;
  FRequires := TStringList.Create;
  ReadPackageInfo(ALibHandle);
end;

//------------------------------------------------------------------------------

destructor TJclPePackageInfo.Destroy;
begin
  FreeAndNil(FContains);
  FreeAndNil(FRequires);
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPePackageInfo.GetContainsCount: Integer;
begin
  Result := FContains.Count;
end;

//------------------------------------------------------------------------------

function TJclPePackageInfo.GetContainsFlags(Index: Integer): Byte;
begin
  Result := Byte(FContains.Objects[Index]);
end;

//------------------------------------------------------------------------------

function TJclPePackageInfo.GetContainsNames(Index: Integer): string;
begin
  Result := FContains[Index];
end;

//------------------------------------------------------------------------------

function TJclPePackageInfo.GetRequiresCount: Integer;
begin
  Result := FRequires.Count;
end;

//------------------------------------------------------------------------------

function TJclPePackageInfo.GetRequiresNames(Index: Integer): string;
begin
  Result := FRequires[Index];
end;

//------------------------------------------------------------------------------

class function TJclPePackageInfo.PackageModuleTypeToString(Flags: Integer): string;
begin
  case Flags and pfModuleTypeMask of
    pfExeModule, pfModuleTypeMask:
      Result := 'Executable';
    pfPackageModule:
      Result := 'Package';
    pfLibraryModule:
      Result := 'Library';
  else
    Result := '';
  end;
end;

//------------------------------------------------------------------------------

class function TJclPePackageInfo.PackageOptionsToString(Flags: Integer): string;
const
  FlagNames: packed array [0..3] of record
    Mask: DWORD;
    Text: PChar;
  end = (
  (Mask: $00000001; Text: 'NeverBuild'),
  (Mask: $00000002; Text: 'DesignOnly'),
  (Mask: $00000004; Text: 'RunOnly'),
  (Mask: $00000008; Text: 'IgnoreDupUnits')
  );
var
  I: Integer;
begin
  Result := '';
  for I := Low(FlagNames) to High(FlagNames) do
    with FlagNames[I] do
      if Flags and Mask <> 0 then
      begin
        if Length(Result) > 0 then
          Result := Result + ', ';
        Result := Result + Text;
      end;
end;

//------------------------------------------------------------------------------

class function TJclPePackageInfo.ProducerToString(Flags: Integer): string;
begin
  case Flags and pfProducerMask of
    pfV3Produced:
      Result := 'V3';
    pfProducerUndefined:
      Result := 'Undefined';
    pfBCB4Produced:
      Result := 'BCB4';
    pfDelphi4Produced:
      Result := 'Delphi4';
  else
    Result := '';
  end;
end;

//------------------------------------------------------------------------------

procedure PackageInfoProc(const Name: string; NameType: TNameType; AFlags: Byte; Param: Pointer);
begin
  with TJclPePackageInfo(Param) do
    case NameType of
      ntContainsUnit:
        FContains.AddObject(Name, Pointer(AFlags));
      ntRequiresPackage:
        FRequires.AddObject(Name, Pointer(AFlags));
    end;
end;

procedure TJclPePackageInfo.ReadPackageInfo(ALibHandle: THandle);
begin
  GetPackageInfo(ALibHandle, Self, FFlags, PackageInfoProc);
  TStringList(FContains).Sort;
  TStringList(FRequires).Sort;
end;

//------------------------------------------------------------------------------

class function TJclPePackageInfo.UnitInfoFlagsToString(UnitFlags: Byte): string;
const
  FlagNames: packed array [0..4] of record
    Mask: Byte;
    Text: PChar;
  end = (
  (Mask: $01; Text: 'Main'),
  (Mask: $02; Text: 'Package'),
  (Mask: $04; Text: 'Weak'),
  (Mask: $08; Text: 'OrgWeak'),
  (Mask: $10; Text: 'Implicit')
  );
var
  I: Integer;
begin
  Result := '';
  for I := Low(FlagNames) to High(FlagNames) do
    with FlagNames[I] do
      if UnitFlags and Mask <> 0 then
      begin
        if Length(Result) > 0 then
          Result := Result + ', ';
        Result := Result + Text;
      end;
end;

//==============================================================================
// TJclPeBorImage
//==============================================================================

procedure TJclPeBorImage.AfterOpen;
var
  HasDVCLAL, HasPACKAGEINFO, HasPACKAGEOPTIONS: Boolean;
  Description: TJclPeResourceItem;
begin
  inherited;
  if StatusOK then
    with ResourceList do
    begin
      HasDVCLAL := (FindResource(rtRCData, 'DVCLAL') <> nil);
      HasPACKAGEINFO := (FindResource(rtRCData, 'PACKAGEINFO') <> nil);
      HasPACKAGEOPTIONS := (FindResource(rtRCData, 'PACKAGEOPTIONS') <> nil);
      FIsPackage := HasPACKAGEINFO and HasPACKAGEOPTIONS;
      FIsBorlandImage := HasDVCLAL or FIsPackage;
      if FIsPackage then
      begin
        Description := FindResource(rtRCData, 'DESCRIPTION');
        if Description <> nil then
          FPackageDescription := PWideChar(Description.List[0].RawEntryData);
      end;
    end;
end;

//------------------------------------------------------------------------------

procedure TJclPeBorImage.Clear;
begin
  FreeAndNil(FPackageInfo);
  FreeLibHandle;
  inherited;
  FIsBorlandImage := False;
  FIsPackage := False;
  FPackageDescription := '';
end;

//------------------------------------------------------------------------------

function TJclPeBorImage.FreeLibHandle: Boolean;
begin
  if FLibHandle <> 0 then
  begin
    Result := FreeLibrary(FLibHandle);
    FLibHandle := 0;
  end else
    Result := True;
end;

//------------------------------------------------------------------------------

function TJclPeBorImage.GetIsTD32DebugPresent: Boolean;
const
  TD32Signature = $39304246; // FB09
var
  DebugDir: TImageDebugDirectory;
  Signature: PDWORD;
begin
  if IsBorlandImage and (DebugList.Count = 1) then
  begin
    DebugDir := DebugList[0];
    Signature := RvaToVa(DebugDir.AddressOfRawData);
    Result := (DebugDir._Type = IMAGE_DEBUG_TYPE_UNKNOWN) and (Signature^ = TD32Signature);
  end else
    Result := False;
end;

//------------------------------------------------------------------------------

function TJclPeBorImage.GetLibHandle: THandle;
begin
  if StatusOK and (FLibHandle = 0) then
  begin
    FLibHandle := LoadLibraryEx(PChar(FileName), 0, LOAD_LIBRARY_AS_DATAFILE);
    if FLibHandle = 0 then
      RaiseLastWin32Error;
  end;
  Result := FLibHandle;
end;

//------------------------------------------------------------------------------

function TJclPeBorImage.GetPackageInfo: TJclPePackageInfo;
begin
  if StatusOK and (FPackageInfo = nil) then
  begin
    GetLibHandle;
    FPackageInfo := TJclPePackageInfo.Create(FLibHandle);
    FreeLibHandle;
  end;
  Result := FPackageInfo;
end;

//==============================================================================
// TJclPeNameSearch
//==============================================================================

function TJclPeNameSearch.CompareName(const FunctionName, ComparedName: string): Boolean;
begin
  Result := PeSmartFunctionNameSame(ComparedName, FunctionName, [scIgnoreCase]);
end;

//------------------------------------------------------------------------------

constructor TJclPeNameSearch.Create(const FunctionName, Path: string; Options: TJclPeNameSearchOptions);
begin
  inherited Create(True);
  FFunctionName := FunctionName;
  FOptions := Options;
  FPath := Path;
  FreeOnTerminate := True;
end;

//------------------------------------------------------------------------------

procedure TJclPeNameSearch.DoFound;
begin
  if Assigned(FOnFound) then
    FOnFound(Self, F_FileName, F_FunctionName, F_Option);
end;

//------------------------------------------------------------------------------

procedure TJclPeNameSearch.DoProcessFile;
begin
  if Assigned(FOnProcessFile) then
    FOnProcessFile(Self, FPeImage);
end;

//------------------------------------------------------------------------------

procedure TJclPeNameSearch.Execute;
var
  PathList: TStringList;
  I: Integer;

  function CompareNameAndNotify(const S: string): Boolean;
  begin
    Result := CompareName(S, FFunctionName);
    if Result and not Terminated then
    begin
      F_FunctionName := S;
      Synchronize(DoFound);
    end;
  end;

  procedure ProcessDirectorySearch(const DirName: string);
  var
    Se: TSearchRec;
    SearchResult: Integer;
    ImportList: TJclPeImportList;
    ExportList: TJclPeExportFuncList;
    I: Integer;
  begin
    SearchResult := FindFirst(DirName, faArchive + faReadOnly, Se);
    try
      while not Terminated and (SearchResult = 0) do
      begin
        F_FileName := PathAddSeparator(ExtractFilePath(DirName)) + Se.Name;
        FPeImage.FileName := F_FileName;
        if Assigned(FOnProcessFile) then
          Synchronize(DoProcessFile);
        if FPeImage.StatusOK then
        begin
          if seExports in FOptions then
          begin
            ExportList := FPeImage.ExportList;
            F_Option := seExports;
            for I := 0 to ExportList.Count - 1 do
            begin
              if Terminated then
                Break;
              CompareNameAndNotify(ExportList[I].Name);
            end;
          end;
          if FOptions * [seImports, seDelayImports, seBoundImports] <> [] then
          begin
            ImportList := FPeImage.ImportList;
            FPeImage.TryGetNamesForOrdinalImports;
            for I := 0 to ImportList.AllItemCount - 1 do
              with ImportList.AllItems[I] do
              begin
                if Terminated then
                  Break;
                case ImportLib.ImportKind of
                  ikImport:
                    if seImports in FOptions then
                    begin
                      F_Option := seImports;
                      CompareNameAndNotify(Name);
                    end;
                  ikDelayImport:
                    if seDelayImports in FOptions then
                    begin
                      F_Option := seDelayImports;
                      CompareNameAndNotify(Name);
                    end;
                  ikBoundImport:
                    if seDelayImports in FOptions then
                    begin
                      F_Option := seBoundImports;
                      CompareNameAndNotify(Name);
                    end;
                end;
              end;
          end;
        end;
        SearchResult := FindNext(Se);
      end;
    finally
      FindClose(Se);
    end;
  end;

begin
  FPeImage := TJclPeImage.Create(True);
  PathList := TStringList.Create;
  try
    PathList.Sorted := True;
    PathList.Duplicates := dupIgnore;
    StrToStrings(FPath, ';', TStrings(PathList));
    for I := 0 to PathList.Count - 1 do
      ProcessDirectorySearch(PathAddSeparator(Trim(PathList[I])) + '*.*');
  finally
    PathList.Free;
    FPeImage.Free;
  end;
end;

//------------------------------------------------------------------------------

procedure TJclPeNameSearch.Start;
begin
  Resume;
end;

//==============================================================================
// PE Image miscellaneous functions
//==============================================================================

function IsValidPeFile(const FileName: TFileName): Boolean;
var
  NtHeaders: TImageNtHeaders;
begin
  Result := PeGetNtHeaders(FileName, NtHeaders);
end;

//------------------------------------------------------------------------------

function PeCreateNameHintTable(const FileName: TFileName): Boolean;
var
  PeImage, ExportsImage: TJclPeImage;
  I: Integer;
  ImportItem: TJclPeImportLibItem;
  Thunk: PImageThunkData;
  OrdinalName: PImageImportByName;
  ExportItem: TJclPeExportFuncItem;
  Cache: TJclPeImagesCache;
begin
  Cache := TJclPeImagesCache.Create;
  try
    PeImage := TJclPeImage.Create(False);
    try
      PeImage.ReadOnlyAccess := False;
      PeImage.FileName := FileName;
      Result := PeImage.ImportList.Count > 0;
      for I := 0 to PeImage.ImportList.Count - 1 do
      begin
        ImportItem := PeImage.ImportList[I];
        if ImportItem.ImportKind = ikBoundImport then
          Continue;
        ExportsImage := Cache[ImportItem.FileName];
        ExportsImage.ExportList.PrepareForFastNameSearch;
        Thunk := ImportItem.ThunkData;
        while Thunk^.Function_ <> 0 do
        begin
          if Thunk^.Ordinal and IMAGE_ORDINAL_FLAG = 0 then
          begin
            case ImportItem.ImportKind of
              ikImport:
                OrdinalName := PImageImportByName(PeImage.RvaToVa(DWORD(Thunk^.AddressOfData)));
              ikDelayImport:
                OrdinalName := PImageImportByName(PeImage.RvaToVa(DWORD(Thunk^.AddressOfData - PeImage.OptionalHeader.ImageBase)));
            else
              OrdinalName := nil;
            end;
            ExportItem := ExportsImage.ExportList.ItemFromName[PChar(@OrdinalName.Name)];
            if ExportItem <> nil then
              OrdinalName.Hint := ExportItem.Hint
            else
              OrdinalName.Hint := 0;
          end;
          Inc(Thunk);
        end;
      end;
    finally
      PeImage.Free;
    end;
  finally
    Cache.Free;
  end;
end;

//------------------------------------------------------------------------------

function PeRebaseImage(const ImageName: TFileName; NewBase, TimeStamp, MaxNewSize: DWORD): TJclRebaseImageInfo;

  function CalculateBaseAddress: DWORD;
  var
    FirstChar: Char;
    ModuleName: string;
  begin
    ModuleName := ExtractFileName(ImageName);
    FirstChar := UpCase(ModuleName[1]);
    if not (FirstChar in ['A'..'Z']) then
      FirstChar := 'A';
    Result := $60000000 + (((Ord(FirstChar) - Ord('A')) div 3) * $1000000);
  end;

begin
  if NewBase = 0 then
    NewBase := CalculateBaseAddress;
  with Result do
  begin
    NewImageBase := NewBase;
    Win32Check(ReBaseImage(PChar(ImageName), nil, True, False, False, MaxNewSize,
      OldImageSize, OldImageBase, NewImageSize, NewImageBase, TimeStamp));
  end;
end;

//------------------------------------------------------------------------------

function PeUpdateCheckSum(const FileName: TFileName): Boolean;
var
  LI: TLoadedImage;
begin
  Result := MapAndLoad(PChar(FileName), nil, @LI, True, False);
  if Result then
    Result := UnMapAndLoad(@LI);
end;

//==============================================================================
// Various simple PE Image functions
//==============================================================================

function CreatePeImage(const FileName: TFileName): TJclPeImage;
begin
  Result := TJclPeImage.Create(True);
  Result.FileName := FileName;
end;

//------------------------------------------------------------------------------

function InternalImportedLibraries(const FileName: TFileName;
  Recursive, FullPathName: Boolean): TStringList;
var
  Cache: TJclPeImagesCache;

  procedure ProcessLibraries(const AFileName: TFileName);
  var
    I: Integer;
    S: string;
    ImportLib: TJclPeImportLibItem;
  begin
    with Cache[AFileName].ImportList do
      for I := 0 to Count - 1 do
      begin
        ImportLib := Items[I];
        if FullPathName then
          S := ImportLib.FileName
        else
          S := ImportLib.Name;
        if Result.IndexOf(S) = -1 then
        begin
          Result.Add(S);
          if Recursive then
            ProcessLibraries(ImportLib.FileName);
        end;
      end;
  end;

begin
  Cache := TJclPeImagesCache.Create;
  try
    Result := TStringList.Create;
    try
      Result.Sorted := True;
      Result.Duplicates := dupIgnore;
      ProcessLibraries(FileName);
    except
      FreeAndNil(Result);
    end;
  finally
    Cache.Free;
  end;
end;

//------------------------------------------------------------------------------

function PeDoesExportFunction(const FileName: TFileName; const FunctionName: string;
  Options: TJclSmartCompOptions): Boolean;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK and Assigned(ExportList.SmartFindName(FunctionName, Options));
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

function PeIsExportFunctionForwardedEx(const FileName: TFileName; const FunctionName: string;
  var ForwardedName: string; Options: TJclSmartCompOptions): Boolean;
var
  ExportItem: TJclPeExportFuncItem;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
    begin
      ExportItem := ExportList.SmartFindName(FunctionName, Options);
      if ExportItem <> nil then
      begin
        Result := ExportItem.IsForwarded;
        ForwardedName := ExportItem.ForwardedName;
      end
      else
      begin
        Result := False;
        ForwardedName := '';
      end;
    end;
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

function PeIsExportFunctionForwarded(const FileName: TFileName; const FunctionName: string;
  Options: TJclSmartCompOptions): Boolean;
var
  Dummy: string;
begin
  Result := PeIsExportFunctionForwardedEx(FileName, FunctionName, Dummy, Options);
end;

//------------------------------------------------------------------------------

function PeDoesImportFunction(const FileName: TFileName; const FunctionName: string;
  const LibraryName: string; Options: TJclSmartCompOptions): Boolean;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
      with ImportList do
      begin
        TryGetNamesForOrdinalImports;
        Result := SmartFindName(FunctionName, LibraryName, Options) <> nil;
      end;
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

function PeDoesImportLibrary(const FileName: TFileName; const LibraryName: string;
  Recursive: Boolean): Boolean;
var
  SL: TStringList;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
    begin
      SL := InternalImportedLibraries(FileName, Recursive, False);
      try
        Result := SL.IndexOf(LibraryName) > -1;
      finally
        SL.Free;
      end;
    end;
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

function PeImportedLibraries(const FileName: TFileName; LibrariesList: TStrings; Recursive, FullPathName: Boolean): Boolean;
var
  SL: TStringList;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
    begin
      SL := InternalImportedLibraries(FileName, Recursive, FullPathName);
      try
        LibrariesList.Assign(SL);
      finally
        SL.Free;
      end;
    end;
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeImportedLibrariesArray(const FileName: TFileName; var LibrariesList: TJclStringArray; Recursive, FullPathName: Boolean): Boolean;
var
  I: Integer;
  SL: TStringList;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
    begin
      SL := InternalImportedLibraries(FileName, Recursive, FullPathName);
      try
        SetLength(LibrariesList, SL.Count);
        for I := 0 to SL.Count - 1 do
          LibrariesList[I] := SL[I];
      finally
        SL.Free;
      end;
    end;
  finally
    Free;
  end;
end;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

//------------------------------------------------------------------------------

function PeImportedFunctions(const FileName: TFileName; FunctionsList: TStrings;
  const LibraryName: string; IncludeLibNames: Boolean): Boolean;
var
  I: Integer;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
      with ImportList do
      begin
        TryGetNamesForOrdinalImports;
        for I := 0 to AllItemCount - 1 do
          with AllItems[I] do
            if ((Length(LibraryName) = 0) or StrSame(ImportLib.Name, LibraryName)) and
              (Name <> '') then
            begin
              if IncludeLibNames then
                FunctionsList.Add(ImportLib.Name + '=' + Name)
              else
                FunctionsList.Add(Name);
            end;
      end;
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeImportedFunctionsArray(const FileName: TFileName; var FunctionsList: TJclStringArray;
  const LibraryName: string; IncludeLibNames: Boolean): Boolean;
var
  I, Cnt: Integer;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
      with ImportList do
      begin
        TryGetNamesForOrdinalImports;
        SetLength(FunctionsList, AllItemCount);
        Cnt := 0;
        for I := 0 to AllItemCount - 1 do
        begin
          with AllItems[I] do
            if ((Length(LibraryName) = 0) or StrSame(ImportLib.Name, LibraryName)) and
              (Name <> '') then
            begin
              if IncludeLibNames then
                FunctionsList[I] := ImportLib.Name + '=' + Name
              else
                FunctionsList[I] := Name;
              Inc(Cnt);
            end;
        end;
        SetLength(FunctionsList, Cnt);
      end;
  finally
    Free;
  end;
end;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

//------------------------------------------------------------------------------

function PeExportedFunctions(const FileName: TFileName; FunctionsList: TStrings): Boolean;
var
  I: Integer;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
      with ExportList do
        for I := 0 to Count - 1 do
          FunctionsList.Add(Items[I].Name);
  finally
    Free;
  end;
end;

//------------------------------------------------------------------------------

{$IFDEF SUPPORTS_DYNAMICARRAYS}
function PeExportedFunctionsArray(const FileName: TFileName; var FunctionsList: TJclStringArray): Boolean;
var
  I: Integer;
begin
  with CreatePeImage(FileName) do
  try
    Result := StatusOK;
    if Result then
      with ExportList do
      begin
        SetLength(FunctionsList, Count);
        for I := 0 to Count - 1 do
          FunctionsList[I] := Items[I].Name;
      end;
  finally
    Free;
  end;
end;
{$ENDIF SUPPORTS_DYNAMICARRAYS}

//------------------------------------------------------------------------------

function PeGetNtHeaders(const FileName: TFileName; var NtHeaders: TImageNtHeaders): Boolean;
var
  FileHandle: THandle;
  Mapping: TJclFileMapping;
  View: TJclFileMappingView;
  HeadersPtr: PImageNtHeaders;
begin
  Result := False;
  FillChar(NtHeaders, SizeOf(NtHeaders), 0);
  FileHandle := FileOpen(FileName, fmOpenRead or fmShareDenyWrite);
  if FileHandle = INVALID_HANDLE_VALUE then
    Exit;
  try
    if GetSizeOfFile(FileHandle) >= SizeOf(TImageDosHeader) then
    begin
      Mapping := TJclFileMapping.Create(FileHandle, '', PAGE_READONLY, 0, nil);
      try
        View := TJclFileMappingView.Create(Mapping, FILE_MAP_READ, 0, 0);
        HeadersPtr := PeMapImgNtHeaders(View.Memory);
        if HeadersPtr <> nil then
        begin
          Result := True;
          NtHeaders := HeadersPtr^;
        end;
      finally
        Mapping.Free;
      end;
    end;
  finally
    FileClose(FileHandle);
  end;
end;

//------------------------------------------------------------------------------

function PeVerifyCheckSum(const FileName: TFileName): Boolean;
begin
  with CreatePeImage(FileName) do
  try
    Result := VerifyCheckSum;
  finally
    Free;
  end;
end;

//==============================================================================
// Mapped image related functions
//==============================================================================

function PeMapImgNtHeaders(const BaseAddress: Pointer): PImageNtHeaders;
begin
  Result := nil;
  if IsBadReadPtr(BaseAddress, SizeOf(TImageDosHeader)) then
    Exit;
  if (PImageDosHeader(BaseAddress)^.e_magic <> IMAGE_DOS_SIGNATURE) or
    (PImageDosHeader(BaseAddress)^._lfanew = 0) then
    Exit;
  Result := PImageNtHeaders(DWORD(BaseAddress) + DWORD(PImageDosHeader(BaseAddress)^._lfanew));
  if IsBadReadPtr(Result, SizeOf(TImageNtHeaders)) or
    (Result^.Signature <> IMAGE_NT_SIGNATURE) then
      Result := nil
end;

//------------------------------------------------------------------------------

function PeMapImgLibraryName(const BaseAddress: Pointer): string;
var
  NtHeaders: PImageNtHeaders;
  DataDir: TImageDataDirectory;
  ExportDir: PImageExportDirectory;
begin
  Result := '';
  NtHeaders := PeMapImgNtHeaders(BaseAddress);
  if NtHeaders = nil then
    Exit;
  DataDir := NtHeaders^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
  if DataDir.Size = 0 then
    Exit;
  ExportDir := PImageExportDirectory(DWORD(BaseAddress) + DataDir.VirtualAddress);
  if IsBadReadPtr(ExportDir, SizeOf(TImageExportDirectory)) or (ExportDir^.Name = 0) then
    Exit;
  Result := PChar(DWORD(BaseAddress) + ExportDir^.Name);
end;

//------------------------------------------------------------------------------

function PeMapImgSections(const NtHeaders: PImageNtHeaders): PImageSectionHeader;
begin
  if NtHeaders = nil then
    Result := nil
  else
    Result := PImageSectionHeader(DWORD(@NtHeaders^.OptionalHeader) +
      NtHeaders^.FileHeader.SizeOfOptionalHeader);
end;

//------------------------------------------------------------------------------

function PeMapImgFindSection(const NtHeaders: PImageNtHeaders;
  const SectionName: string): PImageSectionHeader;
var
  Header: PImageSectionHeader;
  I: Integer;
  P: PChar;
begin
  Result := nil;
  if NtHeaders <> nil then
  begin
    P := PChar(SectionName);
    Header := PeMapImgSections(NtHeaders);
    with NtHeaders^ do
      for I := 1 to FileHeader.NumberOfSections do
        if StrIComp(PChar(@Header^.Name), P) = 0 then
        begin
          Result := Header;
          Break;
        end else
          Inc(Header);
  end;
end;

//==============================================================================
// TJclPeSectionStream
//==============================================================================

constructor TJclPeSectionStream.Create(Instance: HMODULE; const ASectionName: string);
begin
  inherited Create;
  Initialize(Instance, ASectionName);
end;

//------------------------------------------------------------------------------

procedure TJclPeSectionStream.Initialize(Instance: HMODULE; const ASectionName: string);
var
  Header: PImageSectionHeader;
  NtHeaders: PImageNtHeaders;
begin
  FInstance := Instance;
  NtHeaders := PeMapImgNtHeaders(Pointer(Instance));
  if NtHeaders = nil then
    raise EJclPeImageError.CreateResRec(@RsPeNotPE);
  Header := PeMapImgFindSection(NtHeaders, ASectionName);
  if Header = nil then
    raise EJclPeImageError.CreateResRecFmt(@RsPeSectionNotFound, [ASectionName]);
  SetPointer(Pointer(FInstance + Header^.VirtualAddress), Header^.SizeOfRawData);
  FSectionHeader := Header^;
end;

//------------------------------------------------------------------------------

function TJclPeSectionStream.Write(const Buffer; Count: Integer): Longint;
begin
  raise EJclPeImageError.CreateResRec(@SCantWriteResourceStreamError);
end;

//==============================================================================
// TJclPeMapImgHookItem
//==============================================================================

destructor TJclPeMapImgHookItem.Destroy;
begin
  if FBaseAddress <> nil then
    InternalUnhook;
  inherited;
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHookItem.InternalUnhook: Boolean;
begin
  Result := TJclPeMapImgHooks.ReplaceImport(FBaseAddress, ModuleName, NewAddress, OriginalAddress);
  if Result then
    FBaseAddress := nil;
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHookItem.Unhook: Boolean;
begin
  Result := InternalUnhook;
  if Result then
    FList.Remove(Self);
end;

//==============================================================================
// TJclPeMapImgHooks
//==============================================================================

type
  PWin9xDebugThunk = ^TWin9xDebugThunk;
  TWin9xDebugThunk = packed record
    PUSH: Byte;    // PUSH instruction opcode ($68)
    Addr: Pointer; // The actual address of the DLL routine
    JMP: Byte;     // JMP instruction opcode ($E9)
    Rel: Integer;  // Relative displacement (a Kernel32 address)
  end;

//------------------------------------------------------------------------------

function TJclPeMapImgHooks.GetItemFromNewAddress(NewAddress: Pointer): TJclPeMapImgHookItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].NewAddress = NewAddress then
    begin
      Result := Items[I];
      Break;
    end;
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHooks.GetItemFromOriginalAddress(OriginalAddress: Pointer): TJclPeMapImgHookItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].OriginalAddress = OriginalAddress then
    begin
      Result := Items[I];
      Break;
    end;
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHooks.GetItems(Index: Integer): TJclPeMapImgHookItem;
begin
  Result := TJclPeMapImgHookItem(inherited Items[Index]);
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHooks.HookImport(Base: Pointer; const ModuleName, FunctionName: string;
  NewAddress: Pointer; var OriginalAddress: Pointer): Boolean;
var
  Item: TJclPeMapImgHookItem;
  ModuleHandle: THandle;
begin
  ModuleHandle := GetModuleHandle(PChar(ModuleName));
  Result := (ModuleHandle <> 0);
  if not Result then
  begin
    SetLastError(ERROR_MOD_NOT_FOUND);
    Exit;
  end;
  OriginalAddress := GetProcAddress(ModuleHandle, PChar(FunctionName));
  Result := (OriginalAddress <> nil);
  if not Result then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;
  Result := (ItemFromOriginalAddress[OriginalAddress] = nil) and (NewAddress <> nil) and
    (OriginalAddress <> NewAddress);
  if not Result then
  begin
    SetLastError(ERROR_ALREADY_EXISTS);
    Exit;
  end;
  if Result then
    Result := ReplaceImport(Base, ModuleName, OriginalAddress, NewAddress);
  if Result then
  begin
    Item := TJclPeMapImgHookItem.Create;
    Item.FBaseAddress := Base;
    Item.FFunctionName := FunctionName;
    Item.FModuleName := ModuleName;
    Item.FOriginalAddress := OriginalAddress;
    Item.FNewAddress := NewAddress;
    Item.FList := Self;
    Add(Item);
  end
  else
    SetLastError(ERROR_INVALID_PARAMETER);
end;

//------------------------------------------------------------------------------

class function TJclPeMapImgHooks.IsWin9xDebugThunk(P: Pointer): Boolean;
begin
  with PWin9xDebugThunk(P)^ do
    Result := (PUSH = $68) and (JMP = $E9);
end;

//------------------------------------------------------------------------------

class function TJclPeMapImgHooks.ReplaceImport(Base: Pointer; ModuleName: string;
  FromProc, ToProc: Pointer): Boolean;
var
  FromProcDebugThunk, ImportThunk: PWin9xDebugThunk;
  IsThunked: Boolean;
  NtHeader: PImageNtHeaders;
  ImportDir: TImageDataDirectory;
  ImportDesc: PImageImportDescriptor;
  CurrName: PChar;
  ImportEntry: PImageThunkData;
  FoundProc: Boolean;
begin
  Result := False;
  FromProcDebugThunk := PWin9xDebugThunk(FromProc);
  IsThunked := not IsWinNT and IsWin9xDebugThunk(FromProcDebugThunk);
  NtHeader := PeMapImgNtHeaders(Base);
  if NtHeader = nil then
    Exit;
  ImportDir := NtHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if ImportDir.VirtualAddress = 0 then
    Exit;
  ImportDesc := PImageImportDescriptor(DWORD(Base) + ImportDir.VirtualAddress);
  while ImportDesc^.Name <> 0 do
  begin
    CurrName := PChar(Base) + ImportDesc^.Name;
    if StrIComp(CurrName, PChar(ModuleName)) = 0 then
    begin
      ImportEntry := PImageThunkData(DWORD(Base) + ImportDesc^.FirstThunk);
      while ImportEntry^.Function_ <> 0 do
      begin
        if IsThunked then
        begin
          ImportThunk := PWin9xDebugThunk(ImportEntry^.Function_);
          FoundProc := IsWin9xDebugThunk(ImportThunk) and (ImportThunk^.Addr = FromProcDebugThunk^.Addr);
        end
        else
          FoundProc := Pointer(ImportEntry^.Function_) = FromProc;
        if FoundProc and not IsBadStringPtr(Pointer(ImportEntry^.Function_), 4) then
        begin
          Pointer(ImportEntry^.Function_) := ToProc;
          Result := True;
        end;
        Inc(ImportEntry);
      end;
    end;
    Inc(ImportDesc);
  end;
end;

//------------------------------------------------------------------------------

function TJclPeMapImgHooks.UnhookByNewAddress(NewAddress: Pointer): Boolean;
var
  Item: TJclPeMapImgHookItem;
begin
  Item := ItemFromNewAddress[NewAddress];
  Result := (Item <> nil) and Item.Unhook;
end;

//==============================================================================
// Image access under a debbuger
//==============================================================================

function InternalReadProcMem(ProcessHandle: THandle; Address: DWORD;
  Buffer: Pointer; Size: Integer): Boolean;
var
  BR: DWORD;
begin
  Result := ReadProcessMemory(ProcessHandle, Pointer(Address), Buffer, Size, BR);
end;

//------------------------------------------------------------------------------

function PeDbgImgNtHeaders(ProcessHandle: THandle; BaseAddress: Pointer;
  var NtHeaders: TImageNtHeaders): Boolean;
var
  DosHeader: TImageDosHeader;
begin
  Result := False;
  FillChar(NtHeaders, SizeOf(NtHeaders), 0);
  FillChar(DosHeader, SizeOf(DosHeader), 0);
  if not InternalReadProcMem(ProcessHandle, DWORD(BaseAddress), @DosHeader, SizeOf(DosHeader)) then
    Exit;
  if DosHeader.e_magic <> IMAGE_DOS_SIGNATURE then
    Exit;
  Result := InternalReadProcMem(ProcessHandle, DWORD(BaseAddress) + DWORD(DosHeader._lfanew),
    @NtHeaders, SizeOf(TImageNtHeaders));
end;

//------------------------------------------------------------------------------

function PeDbgImgLibraryName(ProcessHandle: THandle; BaseAddress: Pointer;
  var Name: string): Boolean;
var
  NtHeaders: TImageNtHeaders;
  DataDir: TImageDataDirectory;
  ExportDir: TImageExportDirectory;
begin
  Name := '';
  Result := PeDbgImgNtHeaders(ProcessHandle, BaseAddress, NtHeaders);
  if not Result then
    Exit;
  DataDir := NtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
  if DataDir.Size = 0 then
    Exit;
  if not InternalReadProcMem(ProcessHandle, DWORD(BaseAddress) + DataDir.VirtualAddress,
    @ExportDir, SizeOf(ExportDir)) then
    Exit;
  if ExportDir.Name = 0 then
    Exit;
  SetLength(Name, MAX_PATH);
  if InternalReadProcMem(ProcessHandle, DWORD(BaseAddress) + ExportDir.Name, PChar(Name), MAX_PATH) then
    StrResetLength(Name)
  else
    Name := '';    
end;

//==============================================================================
// Borland name unmangling for Delphi packages
//==============================================================================

function PeBorUnmangleName(const Name: string; var Unmangled: string;
  var Description: TJclBorUmDescription; var BasePos: Integer): TJclBorUmResult;
const
  ValidSymbolName = ['_', '0'..'9', 'A'..'Z', 'a'..'z'];
var
  NameP, NameU, NameUFirst: PChar;
  QualifierFound, LinkProcFound: Boolean;

  procedure MarkQualifier;
  begin
    if not QualifierFound then
    begin
      QualifierFound := True;
      BasePos := NameU - NameUFirst + 2;
    end;
  end;

  procedure ReadSpecialSymbol;
  var
    SymbolLength: Integer;
  begin
    SymbolLength := 0;
    while NameP^ in ['0'..'9'] do
    begin
      SymbolLength := SymbolLength * 10 + Ord(NameP^) - 48;
      Inc(NameP);
    end;
    while (SymbolLength > 0) and (NameP^ <> #0) do
    begin
      if NameP^ = '@' then
      begin
        MarkQualifier;
        NameU^ := '.';
      end else
        NameU^ := NameP^;
      Inc(NameP);
      Inc(NameU);
      Dec(SymbolLength);
    end;
  end;

  procedure ReadRTTI;
  begin
    if StrLComp(NameP, '$xp$', 4) = 0 then
    begin
      Inc(NameP, 4);
      Description.Kind := skRTTI;
      QualifierFound := False;
      ReadSpecialSymbol;
      if QualifierFound then
        Include(Description.Modifiers, smQualified);
    end else
      Result := urError;
  end;

  procedure ReadNameSymbol;
  begin
    if NameP^ = '@' then
    begin
      LinkProcFound := True;
      Inc(NameP);
    end;
    while NameP^ in ValidSymbolName do
    begin
      NameU^ := NameP^;
      Inc(NameP);
      Inc(NameU);
    end;
  end;

  procedure ReadName;
  begin
    Description.Kind := skData;
    QualifierFound := False;
    LinkProcFound := False;
    repeat
      ReadNameSymbol;
      if LinkProcFound and not QualifierFound then
        LinkProcFound := False;
      case NameP^ of
        '@':
          case (NameP + 1)^ of
            #0:
              begin
                Description.Kind := skVTable;
                Break;
              end;
            '$':
              begin
                if (NameP + 2)^ = 'b' then
                begin
                  case (NameP + 3)^ of
                    'c':
                      Description.Kind := skConstructor;
                    'd':
                      Description.Kind := skDestructor;
                  end;
                  Inc(NameP, 6);
                end else
                  Description.Kind := skFunction;
                Break; // no parameters unmangling yet
              end;
          else
            MarkQualifier;
            NameU^ := '.';
            Inc(NameU);
            Inc(NameP);
          end;
        '$':
          begin
            Description.Kind := skFunction;
            Break; // no parameters unmangling yet
          end;
      else
        Break;
      end;
    until False;
    if QualifierFound then
      Include(Description.Modifiers, smQualified);
    if LinkProcFound then
      Include(Description.Modifiers, smLinkProc);
  end;

begin
  NameP := PChar(Name);
  Result := urError;
  case NameP^ of
    '@':
      Result := urOk;
    '?':
      Result := urMicrosoft;
    '_', 'A'..'Z', 'a'..'z':
      Result := urNotMangled;
  end;
  if Result <> urOk then
    Exit;
  Inc(NameP);
  SetLength(UnMangled, 1024);
  NameU := Pointer(UnMangled);
  NameUFirst := NameU;
  Description.Modifiers := [];                 
  BasePos := 1;
  case NameP^ of
    '$':
      ReadRTTI;
    '_', 'A'..'Z', 'a'..'z':
      ReadName;
  else
    Result := urError;
  end;
  NameU^ := #0;
  StrResetLength(Unmangled);
end;

//------------------------------------------------------------------------------

function PeBorUnmangleName(const Name: string; var Unmangled: string;
  var Description: TJclBorUmDescription): TJclBorUmResult;
var
  BasePos: Integer;
begin
  Result := PeBorUnmangleName(Name, Unmangled, Description, BasePos);
end;

//------------------------------------------------------------------------------

function PeBorUnmangleName(const Name: string; var Unmangled: string): TJclBorUmResult;
var
  Description: TJclBorUmDescription;
  BasePos: Integer;
begin
  Result := PeBorUnmangleName(Name, Unmangled, Description, BasePos);
end;

//------------------------------------------------------------------------------

function PeBorUnmangleName(const Name: string): string;
var
  Unmangled: string;
  Description: TJclBorUmDescription;
  BasePos: Integer;
begin
  if PeBorUnmangleName(Name, Unmangled, Description, BasePos) = urOk then
    Result := Unmangled
  else
    Result := '';
end;

//------------------------------------------------------------------------------

function PeIsNameMangled(const Name: string): TJclPeUmResult;
begin
  Result := umNotMangled;
  if Length(Name) > 0 then
    case Name[1] of
      '@':
        Result := umBorland;
      '?':
        Result := umMicrosoft;
    end;
end;

//------------------------------------------------------------------------------

function PeUnmangleName(const Name: string; var Unmangled: string): TJclPeUmResult;
var
  Res: DWORD;
begin
  Result := umNotMangled;
  case PeBorUnmangleName(Name, Unmangled) of
    urOk:
      Result := umBorland;
    urMicrosoft:
      begin
        SetLength(Unmangled, 2048);
        Res := UnDecorateSymbolName(PChar(Name), PChar(Unmangled), 2048, UNDNAME_NAME_ONLY);
        if Res > 0 then
        begin
          StrResetLength(Unmangled);
          Result := umMicrosoft;
        end else
          Unmangled := '';
      end;
  end;
  if Result = umNotMangled then
    Unmangled := Name;
end;

//------------------------------------------------------------------------------


end.
