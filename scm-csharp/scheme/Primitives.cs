namespace scheme;

public class Primitives
{
    private Dictionary<string, Object> primitives = new();

    public Primitives()
    {
    }
    
    public void Init(Modules modules)
    {
        Bind("*error-port*", Console.Error);
        Bind("*input-port*", new TextStream(Console.In, "{stdin}"));
        Bind("*output-port*", Console.Out);
        Bind("E", Math.E);
        Bind("PI", Math.PI);
        Bind("apply", GetApply());
        Bind("call-with-current-continuation", GetCallCC());
        Bind("call-with-values", GetCallWithValues());
        Bind("field-sep", new char[] { Path.PathSeparator });
        Bind("line-sep", Environment.NewLine.ToCharArray());
        Bind("nil", Value.NIL);
        Bind("path-sep", new char[] { Path.DirectorySeparatorChar });
        Bind(new PrimitiveAbandonedMutexExceptionP());
        Bind(new PrimitiveAbsolutePath());
        Bind(new PrimitiveAcos());
        Bind(new PrimitiveAdd());
        Bind(new PrimitiveAesCbcDecrypt());
        Bind(new PrimitiveAesCbcEncrypt());
        Bind(new PrimitiveAesEcbDecrypt());
        Bind(new PrimitiveAesEcbEncrypt());
        Bind(new PrimitiveAesGcmDecrypt());
        Bind(new PrimitiveAesGcmEncrypt());
        Bind(new PrimitiveAppend());
        Bind(new PrimitiveArithmeticShift());
        Bind(new PrimitiveAsin());
        Bind(new PrimitiveAtan());
        Bind(new PrimitiveBase64Decode());
        Bind(new PrimitiveBase64Encode());
        Bind(new PrimitiveBaseName());
        Bind(new PrimitiveBinaryPortP());
        Bind(new PrimitiveBitCount());
        Bind(new PrimitiveBitwiseAnd());
        Bind(new PrimitiveBitwiseIor());
        Bind(new PrimitiveBitwiseNot());
        Bind(new PrimitiveBitwiseXor());
        Bind(new PrimitiveBooleanP());
        Bind(new PrimitiveBoundIdentifierEqP());
        Bind(new PrimitiveBoundP(modules));
        Bind(new PrimitiveBytevector());
        Bind(new PrimitiveBytevectorAppend());
        Bind(new PrimitiveBytevectorCopy());
        Bind(new PrimitiveBytevectorCopyB());
        Bind(new PrimitiveBytevectorLength());
        Bind(new PrimitiveBytevectorP());
        Bind(new PrimitiveBytevectorU8Ref());
        Bind(new PrimitiveBytevectorU8SetB());
        Bind(new PrimitiveCaar());
        Bind(new PrimitiveCadar());
        Bind(new PrimitiveCadr());
        Bind(new PrimitiveCar());
        Bind(new PrimitiveCdr());
        Bind(new PrimitiveCeiling());
        Bind(new PrimitiveChaCha20Poly1305Decrypt());
        Bind(new PrimitiveChaCha20Poly1305Encrypt());
        Bind(new PrimitiveCharAlphabeticP());
        Bind(new PrimitiveCharDowncase());
        Bind(new PrimitiveCharEqP());
        Bind(new PrimitiveCharFoldcase());
        Bind(new PrimitiveCharGreaterEqP());
        Bind(new PrimitiveCharGreaterP());
        Bind(new PrimitiveCharLessEqP());
        Bind(new PrimitiveCharLessP());
        Bind(new PrimitiveCharLowerCaseP());
        Bind(new PrimitiveCharNumericP());
        Bind(new PrimitiveCharP());
        Bind(new PrimitiveCharToInteger());
        Bind(new PrimitiveCharUpcase());
        Bind(new PrimitiveCharUpperCaseP());
        Bind(new PrimitiveCharWhitespaceP());
        Bind(new PrimitiveCloseInputPort());
        Bind(new PrimitiveCloseInputZip());
        Bind(new PrimitiveCloseJson());
        Bind(new PrimitiveCloseOutputPort());
        Bind(new PrimitiveCloseOutputZip());
        Bind(new PrimitiveCloseXml());
        Bind(new PrimitiveCommandLine());
        Bind(new PrimitiveCompile(modules));
        Bind(new PrimitiveComplexAngle());
        Bind(new PrimitiveComplexImagPart());
        Bind(new PrimitiveComplexMagnitude());
        Bind(new PrimitiveComplexP());
        Bind(new PrimitiveComplexRealPart());
        Bind(new PrimitiveConditionVariableBroadcastB());
        Bind(new PrimitiveConditionVariableName());
        Bind(new PrimitiveConditionVariableP());
        Bind(new PrimitiveConditionVariableSignalB());
        Bind(new PrimitiveConditionVariableSpecific());
        Bind(new PrimitiveConditionVariableSpecificSetB());
        Bind(new PrimitiveConsoleEchoB());
        Bind(new PrimitiveConsoleReadPassword());
        Bind(new PrimitiveCons());
        Bind(new PrimitiveCopyDirectory());
        Bind(new PrimitiveCopyFile());
        Bind(new PrimitiveCos());
        Bind(new PrimitiveCrc32());
        Bind(new PrimitiveCreateModule(modules));
        Bind(new PrimitiveCsvLineToFields());
        Bind(new PrimitiveCurrentDirectory());
        Bind(new PrimitiveCurrentModule(modules));
        Bind(new PrimitiveCurrentNanosecond());
        Bind(new PrimitiveCurrentPid());
        Bind(new PrimitiveCurrentSourceLocation());
        Bind(new PrimitiveCurrentThread());
        Bind(new PrimitiveDatumToSyntax());
        Bind(new PrimitiveDeflateCompress());
        Bind(new PrimitiveDeflateDecompress());
        Bind(new PrimitiveDeleteDirectory());
        Bind(new PrimitiveDeleteFile());
        Bind(new PrimitiveDictClear());
        Bind(new PrimitiveDictContains());
        Bind(new PrimitiveDictEntries());
        Bind(new PrimitiveDictGet());
        Bind(new PrimitiveDictKeys());
        Bind(new PrimitiveDictPut());
        Bind(new PrimitiveDictSize());
        Bind(new PrimitiveDictValues());
        Bind(new PrimitiveDigitValue());
        Bind(new PrimitiveDirectoryDirectories());
        Bind(new PrimitiveDirectoryEntries());
        Bind(new PrimitiveDirectoryExists());
        Bind(new PrimitiveDirectoryFiles());
        Bind(new PrimitiveDirectoryName());
        Bind(new PrimitiveDisassemble(modules));
        Bind(new PrimitiveDisplay(modules));
        Bind(new PrimitiveDiv());
        Bind(new PrimitiveDoImportSet(modules));
        Bind(new PrimitiveDoc(modules));
        Bind(new PrimitiveEOFObjectP());
        Bind(new PrimitiveEnvironment(modules));
        Bind(new PrimitiveEqP());
        Bind(new PrimitiveEqualP());
        Bind(new PrimitiveEqvP());
        Bind(new PrimitiveError());
        Bind(new PrimitiveErrorObjectIrritants());
        Bind(new PrimitiveErrorObjectMessage());
        Bind(new PrimitiveErrorObjectP());
        Bind(new PrimitiveEval(modules));
        Bind(new PrimitiveExact());
        Bind(new PrimitiveExactP());
        Bind(new PrimitiveExceptionHandlersGet());
        Bind(new PrimitiveExceptionHandlersSet());
        Bind(new PrimitiveExit());
        Bind(new PrimitiveExpt());
        Bind(new PrimitiveFeaturesList());
        Bind(new PrimitiveFileErrorP());
        Bind(new PrimitiveFileExists());
        Bind(new PrimitiveFileModificationDate());
        Bind(new PrimitiveFileModificationTimestamp());
        Bind(new PrimitiveFileLock());
        Bind(new PrimitiveFileSize());
        Bind(new PrimitiveFileSymlinkP());
        Bind(new PrimitiveFileUnlock());
        Bind(new PrimitiveFirst());
        Bind(new PrimitiveFloor());
        Bind(new PrimitiveFlushOutputPort(modules));
        Bind(new PrimitiveFormat(modules));
        Bind(new PrimitiveFreeIdentifierEqP(modules));
        Bind(new PrimitiveGenerateTemporaries());
        Bind(new PrimitiveGensym());
        Bind(new PrimitiveGetBytes());
        Bind(new PrimitiveGetCode());
        Bind(new PrimitiveGetEnvironmentVariable());
        Bind(new PrimitiveGetEnvironmentVariables());
        Bind(new PrimitiveGetLambdaEnv());
        Bind(new PrimitiveGetOutputBytevector());
        Bind(new PrimitiveGetOutputString());
        Bind(new PrimitiveGetOutputZipBytevector());
        Bind(new PrimitiveGetProperty());
        Bind(new PrimitiveGetPropertyList());
        Bind(new PrimitiveGetToken(modules));
        Bind(new PrimitiveGzipCompress());
        Bind(new PrimitiveGzipDecompress());
        Bind(new PrimitiveHMACSHA256());
        Bind(new PrimitiveHashTableClearB());
        Bind(new PrimitiveHashTableComparator());
        Bind(new PrimitiveHashTableCopy());
        Bind(new PrimitiveHashTableDeleteB());
        Bind(new PrimitiveHashTableExistsP());
        Bind(new PrimitiveHashTableKeys());
        Bind(new PrimitiveHashTableP());
        Bind(new PrimitiveHashTableRef());
        Bind(new PrimitiveHashTableRefDefault());
        Bind(new PrimitiveHashTableSetB());
        Bind(new PrimitiveHashTableSetComparatorB());
        Bind(new PrimitiveHashTableSize());
        Bind(new PrimitiveHashTableToAlist());
        Bind(new PrimitiveHashTableValues());
        Bind(new PrimitiveHtmlEscape());
        Bind(new PrimitiveHttpGet());
        Bind(new PrimitiveHttpPost());
        Bind(new PrimitiveHttpRequestBody());
        Bind(new PrimitiveHttpRequestBodyBytes());
        Bind(new PrimitiveHttpRequestHeaders());
        Bind(new PrimitiveHttpRequestMethod());
        Bind(new PrimitiveHttpRequestP());
        Bind(new PrimitiveHttpRequestUrl());
        Bind(new PrimitiveHttpResponseBody());
        Bind(new PrimitiveHttpResponseHeaders());
        Bind(new PrimitiveHttpResponseP());
        Bind(new PrimitiveHttpResponseStatus());
        Bind(new PrimitiveHttpSend());
        Bind(new PrimitiveIdentifierP());
        Bind(new PrimitiveInclude(modules));
        Bind(new PrimitiveIncludeCi(modules));
        Bind(new PrimitiveInexact());
        Bind(new PrimitiveInputPortOpenP());
        Bind(new PrimitiveInputPortP());
        Bind(new PrimitiveInstructionArg1());
        Bind(new PrimitiveInstructionArg2());
        Bind(new PrimitiveInstructionOpcode());
        Bind(new PrimitiveIntegerLength());
        Bind(new PrimitiveIntegerP());
        Bind(new PrimitiveIntegerToChar());
        Bind(new PrimitiveJiffy());
        Bind(new PrimitiveJoinTimeoutExceptionP());
        Bind(new PrimitiveJsonAttribute());
        Bind(new PrimitiveJsonNextObject());
        Bind(new PrimitiveKill());
        Bind(new PrimitiveLambdaP());
        Bind(new PrimitiveLength());
        Bind(new PrimitiveListP());
        Bind(new PrimitiveListRef());
        Bind(new PrimitiveLoad(modules));
        Bind(new PrimitiveLoadModule(modules));
        Bind(new PrimitiveLocalTzOffset());
        Bind(new PrimitiveLog());
        Bind(new PrimitiveMD5Hash());
        Bind(new PrimitiveMacroexpand(modules));
        Bind(new PrimitiveMakeBytevector());
        Bind(new PrimitiveMakeConditionVariable());
        Bind(new PrimitiveMakeDict());
        Bind(new PrimitiveMakeDirectory());
        Bind(new PrimitiveMakeErrorObject());
        Bind(new PrimitiveMakeHashTable());
        Bind(new PrimitiveMakeHttpRequest());
        Bind(new PrimitiveMakeHttpResponse());
        Bind(new PrimitiveMakeInstruction());
        Bind(new PrimitiveMakeMutex());
        Bind(new PrimitiveMakeParameterCore());
        Bind(new PrimitiveMakePolar());
        Bind(new PrimitiveMakeRecord());
        Bind(new PrimitiveMakeRectangular());
        Bind(new PrimitiveMakeString());
        Bind(new PrimitiveMakeSymlink());
        Bind(new PrimitiveMakeThread(modules));
        Bind(new PrimitiveMakeVector());
        Bind(new PrimitiveMember());
        Bind(new PrimitiveMemq());
        Bind(new PrimitiveMemv());
        Bind(new PrimitiveModuleBind(modules));
        Bind(new PrimitiveModuleBindings(modules));
        Bind(new PrimitiveModuleDefinedBindings(modules));
        Bind(new PrimitiveModuleExportBindings(modules));
        Bind(new PrimitiveModuleExports(modules));
        Bind(new PrimitiveModuleImportBindings(modules));
        Bind(new PrimitiveModuleRef(modules));
        Bind(new PrimitiveModulo());
        Bind(new PrimitiveMonotonicNanosecond());
        Bind(new PrimitiveMoveDirectory());
        Bind(new PrimitiveMoveFile());
        Bind(new PrimitiveMul());
        Bind(new PrimitiveMutexLockB());
        Bind(new PrimitiveMutexName());
        Bind(new PrimitiveMutexP());
        Bind(new PrimitiveMutexSpecific());
        Bind(new PrimitiveMutexSpecificSetB());
        Bind(new PrimitiveMutexState());
        Bind(new PrimitiveMutexUnlockB());
        Bind(new PrimitiveNewline(modules));
        Bind(new PrimitiveNormalizedPath());
        Bind(new PrimitiveNot());
        Bind(new PrimitiveNullP());
        Bind(new PrimitiveNumberP());
        Bind(new PrimitiveNumberToString());
        Bind(new PrimitiveNumequal());
        Bind(new PrimitiveNumgreater());
        Bind(new PrimitiveNumgreaterequal());
        Bind(new PrimitiveNumless());
        Bind(new PrimitiveNumlessequal());
        Bind(new PrimitiveOpenBinaryInputFile());
        Bind(new PrimitiveOpenBinaryOutputFile());
        Bind(new PrimitiveOpenInputBytevector());
        Bind(new PrimitiveOpenInputFile());
        Bind(new PrimitiveOpenInputString());
        Bind(new PrimitiveOpenInputZipFile());
        Bind(new PrimitiveOpenJsonFile());
        Bind(new PrimitiveOpenJsonString());
        Bind(new PrimitiveOpenOutputBytevector());
        Bind(new PrimitiveOpenOutputFile());
        Bind(new PrimitiveOpenOutputString());
        Bind(new PrimitiveOpenOutputZipBytevector());
        Bind(new PrimitiveOpenOutputZipFile());
        Bind(new PrimitiveOpenXmlBytevector());
        Bind(new PrimitiveOpenXmlFile());
        Bind(new PrimitiveOpenXmlString());
        Bind(new PrimitiveOutputPortOpenP());
        Bind(new PrimitiveOutputPortP());
        Bind(new PrimitivePBKDF2SHA256());
        Bind(new PrimitivePairP());
        Bind(new PrimitivePairSource());
        Bind(new PrimitiveParentPid());
        Bind(new PrimitivePathExistsP());
        Bind(new PrimitivePeekChar(modules));
        Bind(new PrimitivePeekU8());
        Bind(new PrimitivePgParseDatarow());
        Bind(new PrimitivePgQuoteLiteral());
        Bind(new PrimitivePgrep());
        Bind(new PrimitivePkill());
        Bind(new PrimitivePortPosition(modules));
        Bind(new PrimitivePrimitive(modules.primitives));
        Bind(new PrimitivePrimitiveP());
        Bind(new PrimitiveProcedureDoc(modules));
        Bind(new PrimitiveProcessAliveQ());
        Bind(new PrimitiveProcessKill());
        Bind(new PrimitiveProcessNanosecond());
        Bind(new PrimitiveProcessPid());
        Bind(new PrimitiveProcessWait());
        Bind(new PrimitivePs());
        Bind(new PrimitivePsInfo());
        Bind(new PrimitiveQuotient());
        Bind(new PrimitiveRaiseFatal());
        Bind(new PrimitiveRandomBytes());
        Bind(new PrimitiveRationalDenominator());
        Bind(new PrimitiveRationalNumerator());
        Bind(new PrimitiveRead(modules));
        Bind(new PrimitiveReadBytevector());
        Bind(new PrimitiveReadBytevectorB());
        Bind(new PrimitiveReadChar(modules));
        Bind(new PrimitiveReadChars(modules));
        Bind(new PrimitiveReadErrorP());
        Bind(new PrimitiveReadLine(modules));
        Bind(new PrimitiveReadSymlink());
        Bind(new PrimitiveReadU8(modules));
        Bind(new PrimitiveRealP());
        Bind(new PrimitiveRecordP());
        Bind(new PrimitiveRecordRef());
        Bind(new PrimitiveRecordSetB());
        Bind(new PrimitiveRemainder());
        Bind(new PrimitiveResetModules(modules));
        Bind(new PrimitiveRound());
        Bind(new PrimitiveRsaDecrypt());
        Bind(new PrimitiveRsaEncrypt());
        Bind(new PrimitiveRsaGenerateKeypair());
        Bind(new PrimitiveRunProgram(modules));
        Bind(new PrimitiveRunProgramCapture());
        Bind(new PrimitiveSHA1Hash());
        Bind(new PrimitiveSHA256Hash());
        Bind(new PrimitiveSecond());
        Bind(new PrimitiveServerInstallShutdownHook());
        Bind(new PrimitiveServerStop());
        Bind(new PrimitiveServerWait());
        Bind(new PrimitiveSetCarB());
        Bind(new PrimitiveSetCdrB());
        Bind(new PrimitiveSetCodeB());
        Bind(new PrimitiveSetCurrentDirectory());
        Bind(new PrimitiveSetCurrentModule(modules));
        Bind(new PrimitiveSetFileModificationTime());
        Bind(new PrimitiveSin());
        Bind(new PrimitiveSocketBinaryInputPort());
        Bind(new PrimitiveSocketBinaryOutputPort());
        Bind(new PrimitiveSocketClose());
        Bind(new PrimitiveSocketInputPort());
        Bind(new PrimitiveSocketOutputPort());
        Bind(new PrimitiveSocketP());
        Bind(new PrimitiveSpecialFolderApplicationData());
        Bind(new PrimitiveSpecialFolderDocuments());
        Bind(new PrimitiveSpecialFolderTemp());
        Bind(new PrimitiveSpecialFolderUserHome());
        Bind(new PrimitiveSqrt());
        Bind(new PrimitiveStartProgram());
        Bind(new PrimitiveString());
        Bind(new PrimitiveStringAppend());
        Bind(new PrimitiveStringContains());
        Bind(new PrimitiveStringCopy());
        Bind(new PrimitiveStringDowncase());
        Bind(new PrimitiveStringEqP());
        Bind(new PrimitiveStringFoldcase());
        Bind(new PrimitiveStringGreaterEqP());
        Bind(new PrimitiveStringGreaterP());
        Bind(new PrimitiveStringJoin());
        Bind(new PrimitiveStringLength());
        Bind(new PrimitiveStringLessEqP());
        Bind(new PrimitiveStringLessP());
        Bind(new PrimitiveStringMatches());
        Bind(new PrimitiveStringP());
        Bind(new PrimitiveStringPrefixP());
        Bind(new PrimitiveStringRef());
        Bind(new PrimitiveStringReplace());
        Bind(new PrimitiveStringSetB());
        Bind(new PrimitiveStringSplit());
        Bind(new PrimitiveStringSplitVector());
        Bind(new PrimitiveStringSuffixP());
        Bind(new PrimitiveStringToDateDays());
        Bind(new PrimitiveStringToDateSeconds());
        Bind(new PrimitiveStringToNumber());
        Bind(new PrimitiveStringToSymbol());
        Bind(new PrimitiveStringToUtf8());
        Bind(new PrimitiveStringUpcase());
        Bind(new PrimitiveSub());
        Bind(new PrimitiveSubstring());
        Bind(new PrimitiveSymbolP());
        Bind(new PrimitiveSymbolStartsWith());
        Bind(new PrimitiveSymbolToString());
        Bind(new PrimitiveSyntaxToDatum());
        Bind(new PrimitiveSysMachineName());
        Bind(new PrimitiveSysNumCPUCores());
        Bind(new PrimitiveSysOSVersion());
        Bind(new PrimitiveSysPlatform());
        Bind(new PrimitiveSysScmTechnology());
        Bind(new PrimitiveSysScmVersion());
        Bind(new PrimitiveSysUserName());
        Bind(new PrimitiveTan());
        Bind(new PrimitiveTcpAccept());
        Bind(new PrimitiveTcpConnect());
        Bind(new PrimitiveTcpHttpServe(modules));
        Bind(new PrimitiveTcpListen());
        Bind(new PrimitiveTcpListenerP());
        Bind(new PrimitiveTdsConnect());
        Bind(new PrimitiveTerminalByteReadyP());
        Bind(new PrimitiveTerminalEnableAnsiB());
        Bind(new PrimitiveTerminalP());
        Bind(new PrimitiveTerminalRawB());
        Bind(new PrimitiveTerminalReadByte());
        Bind(new PrimitiveTerminalSize());
        Bind(new PrimitiveTerminatedThreadExceptionP());
        Bind(new PrimitiveTextualPortP());
        Bind(new PrimitiveThreadJoinB());
        Bind(new PrimitiveThreadName());
        Bind(new PrimitiveThreadNanosecond());
        Bind(new PrimitiveThreadP());
        Bind(new PrimitiveThreadSleepB());
        Bind(new PrimitiveThreadSpecific());
        Bind(new PrimitiveThreadSpecificSetB());
        Bind(new PrimitiveThreadStartB());
        Bind(new PrimitiveThreadTerminateB());
        Bind(new PrimitiveThreadYieldB());
        Bind(new PrimitiveTimestamp());
        Bind(new PrimitiveTimestampToString());
        Bind(new PrimitiveTruncate());
        Bind(new PrimitiveUncaughtExceptionP());
        Bind(new PrimitiveUncaughtExceptionReason());
        Bind(new PrimitiveUtf8ToString());
        Bind(new PrimitiveValues());
        Bind(new PrimitiveVector());
        Bind(new PrimitiveVectorLength());
        Bind(new PrimitiveVectorP());
        Bind(new PrimitiveVectorRef());
        Bind(new PrimitiveVectorSetB());
        Bind(new PrimitiveWhich());
        Bind(new PrimitiveWindersGet());
        Bind(new PrimitiveWindersSet());
        Bind(new PrimitiveWrite(modules));
        Bind(new PrimitiveWriteBytevector());
        Bind(new PrimitiveWriteChar(modules));
        Bind(new PrimitiveWriteShared(modules));
        Bind(new PrimitiveWriteSimple(modules));
        Bind(new PrimitiveWriteString(modules));
        Bind(new PrimitiveWriteU8());
        Bind(new PrimitiveWsAccept());
        Bind(new PrimitiveWsClose());
        Bind(new PrimitiveWsConnect());
        Bind(new PrimitiveWsP());
        Bind(new PrimitiveWsReceive());
        Bind(new PrimitiveWsSend());
        Bind(new PrimitiveXmlAttribute());
        Bind(new PrimitiveXmlName());
        Bind(new PrimitiveXmlNodeType());
        Bind(new PrimitiveXmlRead());
        Bind(new PrimitiveXmlReadTo());
        Bind(new PrimitiveXmlValue());
        Bind(new PrimitiveXorKey());
        Bind(new PrimitiveZipAddBinaryEntry());
        Bind(new PrimitiveZipAddStoredEntry());
        Bind(new PrimitiveZipAddTextEntry());
        Bind(new PrimitiveZipEntryNames());
        Bind(new PrimitiveZipReadEntryBytevector());
        Bind(new PrimitiveZlibCompress());
        Bind(new PrimitiveZlibDecompress());
    }

    public Object GetPrimitive(SourcePos? pos, string name)
    {
        if (primitives.TryGetValue(name, out var value))
        {
            return value;
        }
        else
        {
            throw new SchemeError(pos, "Primitives: " + name + " is not a primitive");
        }
    }

    public Object GetPrimitive(string name)
    {
        if (primitives.TryGetValue(name, out var value))
        {
            return value;
        }
        else
        {
            throw new SchemeError("Primitives: " + name + " is not a primitive");
        }
    }

    public bool HasPrimitive(string name)
    {
        return primitives.ContainsKey(name);
    }
    
    private object GetCallCC()
    {
        List<Instruction> instructions = new();
        instructions.Add(new Instruction(Opcode.ARGS, 1));
        instructions.Add(new Instruction(Opcode.CC));
        instructions.Add(new Instruction(Opcode.LVAR, 0, 0));
        instructions.Add(new Instruction(Opcode.CALLJ, 1));
        Lambda callcc = new(Value.NIL, instructions)
        {
            name = "call-with-current-continuation",
            doc = "Syntax: (call-with-current-continuation proc)\nLibrary: (scheme base)\nDescription: Calls proc with the current continuation as its argument.\n  The continuation is a procedure that, when called with a value, returns\n  that value to the point where call/cc was invoked.\nExample:\n  (call-with-current-continuation (lambda (k) (k 42))) => 42"
        };
        return callcc;
    }

    private object GetApply()
    {
        List<Instruction> instructions = new();
        instructions.Add(new Instruction(Opcode.ARGSDOT, 1));
        instructions.Add(new Instruction(Opcode.FLATTEN_APPLY, 0, 1));
        instructions.Add(new Instruction(Opcode.LVAR, 0, 0));
        instructions.Add(new Instruction(Opcode.CALLJ, -1));
        Lambda apply = new(Value.NIL, instructions)
        {
            name = "apply",
            doc = "Syntax: (apply proc arg1 ... args)\nLibrary: (scheme base)\nDescription: Calls proc with the given arguments. The last argument must\n  be a list, whose elements are appended to the preceding arguments.\nExample:\n  (apply + 1 2 '(3 4)) => 10"
        };
        return apply;
    }

    private object GetCallWithValues()
    {
        List<Instruction> instructions = new();
        instructions.Add(new Instruction(Opcode.ARGS, 2));
        instructions.Add(new Instruction(Opcode.SAVE, 4));
        instructions.Add(new Instruction(Opcode.LVAR, 0, 0));
        instructions.Add(new Instruction(Opcode.CALLJ, 0));
        instructions.Add(new Instruction(Opcode.FLATTEN_MULTVALS, 0, 1));
        instructions.Add(new Instruction(Opcode.LVAR, 0, 1));
        instructions.Add(new Instruction(Opcode.CALLJ, -1));
        Lambda apply = new(Value.NIL, instructions)
        {
            name = "call-with-values",
            doc = "Syntax: (call-with-values producer consumer)\nLibrary: (scheme base)\nDescription: Calls producer with no arguments. The producer must return\n  zero or more values. The consumer is then called with those values as\n  arguments. Returns the result of consumer.\nExample:\n  (call-with-values (lambda () (values 1 2)) +) => 3"
        };
        return apply;
    }

    private void Bind(Primitive primitive)
    {
        Bind(primitive.Name(), primitive);
    }

    private void Bind(string name, Object value)
    {
        if (primitives.ContainsKey(name))
        {
            throw new SchemeError("Primitives: duplicate " + name);
        }
        primitives[name] = value;
    }

    public List<string> AllPrimitives()
    {
        return primitives.Keys.ToList();
    }
}
