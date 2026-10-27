#!/usr/bin/env python3
"""Dependency-free native Xcode app + static core/DSP + XCTest project.
Standard build phases only. Refuses to overwrite an edited project.
SwiftPM remains the verified command-line build on this CLT-only host.
"""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parent.parent
out=root/'SurBox.xcodeproj'
assert not (out/'project.pbxproj').exists(), 'Preserve existing Xcode project edits'
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def obj(s,**v):
    key=uid(s); objects[key]=v; return key

def configs(name,settings):
    ids=[]
    for mode in ['Debug','Release']:
        s=dict(settings,SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O',DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym')
        if mode=='Debug': s.update(ENABLE_TESTABILITY='YES',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        ids.append(obj(name+mode,isa='XCBuildConfiguration',name=mode,buildSettings=s))
    return obj(name+'configs',isa='XCConfigurationList',buildConfigurations=ids,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
project=uid('project'); main=uid('main'); products=uid('products')
common=dict(MACOSX_DEPLOYMENT_TARGET='14.0',SDKROOT='macosx',SWIFT_VERSION='5.0',CLANG_ENABLE_MODULES='YES',CLANG_CXX_LANGUAGE_STANDARD='c++17',CODE_SIGN_STYLE='Automatic',SWIFT_INCLUDE_PATHS='$(inherited) $(SRCROOT)/Sources/SurBoxDSP/include',HEADER_SEARCH_PATHS='$(inherited) $(SRCROOT)/Sources/SurBoxDSP/include')
target_ids={n:uid(n+'target') for n in ['SurBoxCore','SurBoxDSP','SurBox','SurBoxCoreTests']}
groups=[]; productrefs=[]
def dep(a,b):
    p=obj(a+b+'proxy',isa='PBXContainerItemProxy',containerPortal=project,proxyType=1,remoteGlobalIDString=target_ids[b],remoteInfo=b)
    return obj(a+b+'dependency',isa='PBXTargetDependency',target=target_ids[b],targetProxy=p)

def target(name,folder,extension,ptype,pname,filetype,extra,deps,resources=False):
    refs=[]; builds=[]
    for path in sorted((root/folder).glob('*'+extension)):
        rel=str(path.relative_to(root)); ref=obj(rel,isa='PBXFileReference',lastKnownFileType='sourcecode.cpp.cpp' if extension=='.cpp' else 'sourcecode.swift',path=rel,sourceTree='SOURCE_ROOT')
        refs.append(ref); builds.append(obj(name+rel,isa='PBXBuildFile',fileRef=ref))
    resourcebuilds=[]
    if resources:
        paths=list((root/'Sources/SurBox/Resources').rglob('*.wav'))+list((root/'Sources/SurBox/Resources').glob('*.json'))+list((root/'Sources/SurBox/Resources').glob('*.txt'))+[root/'Resources/AppIcon.icns']
        for p in paths:
            rel=str(p.relative_to(root)); ref=obj(rel,isa='PBXFileReference',lastKnownFileType='file',path=rel,sourceTree='SOURCE_ROOT'); refs.append(ref); resourcebuilds.append(obj(name+rel,isa='PBXBuildFile',fileRef=ref))
    groups.append(obj(name+'group',isa='PBXGroup',name=name,children=refs,sourceTree='<group>'))
    sourcephase=obj(name+'sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)
    links=[obj(name+d+'link',isa='PBXBuildFile',fileRef=uid(d+'product')) for d in deps]
    linkphase=obj(name+'links',isa='PBXFrameworksBuildPhase',buildActionMask=2147483647,files=links,runOnlyForDeploymentPostprocessing=0)
    resourcesphase=obj(name+'resources',isa='PBXResourcesBuildPhase',buildActionMask=2147483647,files=resourcebuilds,runOnlyForDeploymentPostprocessing=0)
    product=obj(name+'product',isa='PBXFileReference',explicitFileType=filetype,path=pname,sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0); productrefs.append(product)
    settings=dict(common,PRODUCT_NAME=name,PRODUCT_BUNDLE_IDENTIFIER='local.surbox.'+name,GENERATE_INFOPLIST_FILE='YES');settings.update(extra)
    objects[target_ids[name]]=dict(isa='PBXNativeTarget',name=name,productName=name,productType=ptype,productReference=product,buildConfigurationList=configs(name,settings),buildPhases=[sourcephase,linkphase,resourcesphase],buildRules=[],dependencies=[dep(name,d) for d in deps])

target('SurBoxCore','Sources/SurBoxCore','.swift','com.apple.product-type.library.static','libSurBoxCore.a','archive.ar',dict(DEFINES_MODULE='YES',SKIP_INSTALL='YES',SWIFT_INSTALL_OBJC_HEADER='NO'),[])
target('SurBoxDSP','Sources/SurBoxDSP','.cpp','com.apple.product-type.library.static','libSurBoxDSP.a','archive.ar',dict(DEFINES_MODULE='YES',SKIP_INSTALL='YES',MODULEMAP_FILE='Sources/SurBoxDSP/include/module.modulemap'),[])
target('SurBox','Sources/SurBox','.swift','com.apple.product-type.application','SurBox.app','wrapper.application',dict(GENERATE_INFOPLIST_FILE='NO',INFOPLIST_FILE='Resources/Info.plist',ENABLE_HARDENED_RUNTIME='YES',ENABLE_APP_SANDBOX='NO',OTHER_LDFLAGS='$(inherited) -lc++'),['SurBoxCore','SurBoxDSP'],True)
target('SurBoxCoreTests','Tests/SurBoxCoreTests','.swift','com.apple.product-type.bundle.unit-test','SurBoxCoreTests.xctest','wrapper.cfbundle',dict(SKIP_INSTALL='YES',OTHER_LDFLAGS='$(inherited) -lc++'),['SurBoxCore','SurBoxDSP'])
objects[products]=dict(isa='PBXGroup',name='Products',children=productrefs,sourceTree='<group>')
objects[main]=dict(isa='PBXGroup',children=groups+[products],sourceTree='<group>')
objects[project]=dict(isa='PBXProject',attributes=dict(BuildIndependentTargetsInParallel='YES',LastUpgradeCheck='1600'),buildConfigurationList=configs('Project',common),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=list(target_ids.values()))
def plist(v,i=0):
    p='\t'*i
    if isinstance(v,dict): return '{\n'+''.join(p+'\t'+json.dumps(str(k))+' = '+plist(x,i+1)+';\n' for k,x in v.items())+p+'}'
    if isinstance(v,list): return '(\n'+''.join(p+'\t'+plist(x,i+1)+',\n' for x in v)+p+')'
    return json.dumps(v) if isinstance(v,str) else str(v)
out.mkdir(parents=True,exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n'+plist(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=project))+'\n')
def buildable(name,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[name]}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:SurBox.xcodeproj"/>'
a=buildable('SurBox','SurBox.app'); t=buildable('SurBoxCoreTests','SurBoxCoreTests.xctest')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{t}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
s=out/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True);(s/'SurBox.xcscheme').write_text(scheme)
print(out)
