import React, { useState, useEffect, useMemo } from 'react';
import {
  Users,
  ShieldCheck,
  RefreshCw,
  Plus,
  Trash2,
  Download,
  Upload,
  Check,
  Copy,
  FileCode,
  GitBranch,
  Package,
  Search,
  KeyRound,
  Smartphone,
  ArrowRightLeft,
  FolderGit2,
  AlertCircle
} from 'lucide-react';

interface StoredAccount {
  identifier: string;
  appleID: string;
  firstName: string;
  lastName: string;
  teamId: string;
  teamName: string;
  teamType: 'Free' | 'Individual' | 'Organization';
  certSerial: string;
  certExpiresDays: number;
  deviceRegistered: boolean;
  adsid: string;
  lastAuthenticated: string;
}

interface InstalledApp {
  id: string;
  name: string;
  bundleId: string;
  version: string;
  accountAppleID: string;
  teamId: string;
  expiresInDays: number;
  appIdsUsed: number;
  lastRefreshed: string;
  category: string;
}

interface RepoFileEntry {
  path: string;
  category: string;
  summary: string;
  exists: boolean;
  lines: number;
  sizeBytes: number;
  content: string;
}

const INITIAL_ACCOUNTS: StoredAccount[] = [
  {
    identifier: 'DSID-884920194',
    appleID: 'primary.dev@icloud.com',
    firstName: 'Alex',
    lastName: 'Mercer',
    teamId: '9K4L8M2P7Q',
    teamName: 'Alex Mercer (Personal Team)',
    teamType: 'Free',
    certSerial: '4F8A9C10D2E4B701',
    certExpiresDays: 342,
    deviceRegistered: true,
    adsid: '001948-22-9a8b7c6d-5e4f-3a2b-1c0d',
    lastAuthenticated: '2026-10-11 08:15 UTC'
  },
  {
    identifier: 'DSID-551039482',
    appleID: 'secondary.sideload@icloud.com',
    firstName: 'Alex',
    lastName: 'Secondary',
    teamId: '3W7X9Y2Z4B',
    teamName: 'Alex Secondary (Personal Team)',
    teamType: 'Free',
    certSerial: '7B2E1D90F4A3C812',
    certExpiresDays: 364,
    deviceRegistered: true,
    adsid: '001552-18-4f3e2d1c-0b9a-8e7d-6c5b',
    lastAuthenticated: '2026-10-11 07:50 UTC'
  }
];

const INITIAL_APPS: InstalledApp[] = [
  {
    id: 'app-sidestore',
    name: 'SideStore',
    bundleId: 'com.SideStore.SideStore',
    version: '0.6.3',
    accountAppleID: 'primary.dev@icloud.com',
    teamId: '9K4L8M2P7Q',
    expiresInDays: 7,
    appIdsUsed: 2,
    lastRefreshed: 'Just now',
    category: 'System'
  },
  {
    id: 'app-livecontainer',
    name: 'LiveContainer',
    bundleId: 'com.livecontainer.LiveContainer',
    version: '2.1.0',
    accountAppleID: 'primary.dev@icloud.com',
    teamId: '9K4L8M2P7Q',
    expiresInDays: 5,
    appIdsUsed: 2,
    lastRefreshed: '2 days ago',
    category: 'Runtime'
  },
  {
    id: 'app-utm',
    name: 'UTM SE',
    bundleId: 'com.utmapp.UTM-SE',
    version: '4.5.4',
    accountAppleID: 'secondary.sideload@icloud.com',
    teamId: '3W7X9Y2Z4B',
    expiresInDays: 3,
    appIdsUsed: 3,
    lastRefreshed: '4 days ago',
    category: 'Virtualization'
  },
  {
    id: 'app-melonx',
    name: 'MeloNX',
    bundleId: 'com.stossy11.MeloNX',
    version: '1.4.2',
    accountAppleID: 'secondary.sideload@icloud.com',
    teamId: '3W7X9Y2Z4B',
    expiresInDays: 6,
    appIdsUsed: 2,
    lastRefreshed: '1 day ago',
    category: 'Emulator'
  }
];

const CATALOG_APPS = [
  {
    name: 'Provenance Emu',
    bundleId: 'org.provenance-emu.provenance',
    version: '3.0.1',
    appIdsRequired: 3,
    category: 'Multi-System Emulator'
  },
  {
    name: 'Flycast iOS',
    bundleId: 'com.chachirie.flycast',
    version: '2.4.0',
    appIdsRequired: 2,
    category: 'Dreamcast Emulator'
  },
  {
    name: 'Yattee',
    bundleId: 'stream.yattee.app',
    version: '1.6.1',
    appIdsRequired: 2,
    category: 'Video Client'
  },
  {
    name: 'StikDebug',
    bundleId: 'com.stik.stikdebug',
    version: '1.2.0',
    appIdsRequired: 1,
    category: 'JIT Debugger'
  }
];

type ActiveSection = 'accounts' | 'apps' | 'workflow' | 'code';

export default function App() {
  const [activeSection, setActiveSection] = useState<ActiveSection>('accounts');
  const [accounts, setAccounts] = useState<StoredAccount[]>(INITIAL_ACCOUNTS);
  const [activeAppleID, setActiveAppleID] = useState<string>(INITIAL_ACCOUNTS[0].appleID);
  const [apps, setApps] = useState<InstalledApp[]>(INITIAL_APPS);

  // Add account modal / form state
  const [showAddAccount, setShowAddAccount] = useState(false);
  const [newAppleID, setNewAppleID] = useState('');
  const [newFirstName, setNewFirstName] = useState('');
  const [newLastName, setNewLastName] = useState('');
  const [newTeamType, setNewTeamType] = useState<'Free' | 'Individual'>('Free');
  const [formError, setFormError] = useState<string | null>(null);

  // Operation state
  const [isRefreshingAll, setIsRefreshingAll] = useState(false);
  const [refreshingAppId, setRefreshingAppId] = useState<string | null>(null);
  const [operationBanner, setOperationBanner] = useState<string | null>(null);

  // Repo files loaded from Vite server
  const [repoFiles, setRepoFiles] = useState<RepoFileEntry[]>([]);
  const [selectedFilePath, setSelectedFilePath] = useState<string>('SideStore/Core/Auth/AuthManager.swift');
  const [fileSearchQuery, setFileSearchQuery] = useState('');
  const [copiedPath, setCopiedPath] = useState<string | null>(null);

  // Workflow trigger state
  const [selectedTrigger, setSelectedTrigger] = useState<'workflow_dispatch' | 'push' | 'pull_request'>('workflow_dispatch');
  const [selectedBranch, setSelectedBranch] = useState('main');
  const [buildConfig, setBuildConfig] = useState<'Release' | 'Debug'>('Release');

  useEffect(() => {
    fetch('/api/repo-files')
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data.files)) {
          setRepoFiles(data.files);
        }
      })
      .catch(() => {
        // Fallback if static preview
      });
  }, []);

  const activeAccount = useMemo(
    () => accounts.find((a) => a.appleID.toLowerCase() === activeAppleID.toLowerCase()) || accounts[0],
    [accounts, activeAppleID]
  );

  const getAppIdsUsedForAccount = (appleID: string) => {
    return apps
      .filter((app) => app.accountAppleID.toLowerCase() === appleID.toLowerCase())
      .reduce((acc, item) => acc + item.appIdsUsed, 0);
  };

  const handleSwitchAccount = (appleID: string) => {
    const target = accounts.find((a) => a.appleID.toLowerCase() === appleID.toLowerCase());
    if (!target) return;
    setActiveAppleID(target.appleID);
    setOperationBanner(
      `Switched active Keychain & CertificateManager session to ${target.appleID} (Team ${target.teamId}, Serial ${target.certSerial}).`
    );
  };

  const handleAddAccount = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const trimmedEmail = newAppleID.trim().toLowerCase();
    if (!trimmedEmail || !trimmedEmail.includes('@')) {
      setFormError('Enter a valid Apple ID email address.');
      return;
    }
    if (accounts.some((a) => a.appleID.toLowerCase() === trimmedEmail)) {
      setFormError('This Apple ID is already saved in Keychain.savedAccounts.');
      return;
    }

    const randomTeam = Array.from({ length: 10 }, () =>
      '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'.charAt(Math.floor(Math.random() * 32))
    ).join('');
    const randomSerial = Array.from({ length: 16 }, () =>
      '0123456789ABCDEF'.charAt(Math.floor(Math.random() * 16))
    ).join('');

    const created: StoredAccount = {
      identifier: `DSID-${Math.floor(100000000 + Math.random() * 900000000)}`,
      appleID: trimmedEmail,
      firstName: newFirstName.trim() || 'SideStore',
      lastName: newLastName.trim() || 'User',
      teamId: randomTeam,
      teamName: `${newFirstName.trim() || 'SideStore'} ${newLastName.trim() || 'User'} (Personal Team)`,
      teamType: newTeamType,
      certSerial: randomSerial,
      certExpiresDays: 365,
      deviceRegistered: true,
      adsid: `001820-${Math.floor(10 + Math.random() * 89)}-a1b2c3d4-e5f6`,
      lastAuthenticated: 'Just now'
    };

    setAccounts((prev) => [...prev, created]);
    setActiveAppleID(created.appleID);
    setNewAppleID('');
    setNewFirstName('');
    setNewLastName('');
    setShowAddAccount(false);
    setOperationBanner(
      `Saved ${created.appleID} to Keychain.savedAccounts and restored active signing certificate ${created.certSerial}.`
    );
  };

  const handleRemoveAccount = (appleID: string) => {
    if (accounts.length <= 1) {
      setOperationBanner('At least one Apple ID remains active in the simulator. Add another account before removing.');
      return;
    }
    const remaining = accounts.filter((a) => a.appleID.toLowerCase() !== appleID.toLowerCase());
    setAccounts(remaining);
    if (activeAppleID.toLowerCase() === appleID.toLowerCase()) {
      setActiveAppleID(remaining[0].appleID);
      setOperationBanner(
        `Removed ${appleID} from Keychain.savedAccounts and automatically promoted ${remaining[0].appleID} as active account.`
      );
    } else {
      setOperationBanner(`Removed ${appleID} from Keychain.savedAccounts without disrupting ${activeAppleID}.`);
    }
  };

  const handleExportAccountJson = (account: StoredAccount) => {
    const payload = {
      version: 1,
      appleID: account.appleID,
      identifier: account.identifier,
      firstName: account.firstName,
      lastName: account.lastName,
      teamId: account.teamId,
      teamName: account.teamName,
      certSerial: account.certSerial,
      adsid: account.adsid,
      deviceRegistered: account.deviceRegistered
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sidestore-account-${account.appleID.replace(/[^a-z0-9]/gi, '_')}.json`;
    a.click();
    URL.revokeObjectURL(url);
    setOperationBanner(`Exported StoredAccountCredentials JSON for ${account.appleID}.`);
  };

  const handleImportSampleAccount = () => {
    const importedEmail = `alt.account.${accounts.length + 1}@icloud.com`;
    if (accounts.some((a) => a.appleID === importedEmail)) return;
    const imported: StoredAccount = {
      identifier: `DSID-${Math.floor(100000000 + Math.random() * 900000000)}`,
      appleID: importedEmail,
      firstName: 'Imported',
      lastName: `Account ${accounts.length + 1}`,
      teamId: `7T9R2K4M${accounts.length + 1}P`,
      teamName: `Imported Account ${accounts.length + 1} (Personal Team)`,
      teamType: 'Free',
      certSerial: `9E3C7A11B0F2D80${accounts.length + 1}`,
      certExpiresDays: 358,
      deviceRegistered: true,
      adsid: `001999-0${accounts.length + 1}-imported-session`,
      lastAuthenticated: 'Imported via JSON'
    };
    setAccounts((prev) => [...prev, imported]);
    setActiveAppleID(imported.appleID);
    setOperationBanner(
      `Imported ${imported.appleID} via AuthManager.importAccountData() without signing out existing ${accounts.length} accounts.`
    );
  };

  const handleRefreshSingleApp = (app: InstalledApp) => {
    setRefreshingAppId(app.id);
    setTimeout(() => {
      setApps((prev) =>
        prev.map((item) =>
          item.id === app.id
            ? { ...item, expiresInDays: 7, lastRefreshed: 'Just now' }
            : item
        )
      );
      setRefreshingAppId(null);
      setOperationBanner(
        `RefreshAppOperation signed "${app.name}" using owning account ${app.accountAppleID} (Team ${app.teamId}) and restored active session ${activeAccount.appleID}.`
      );
    }, 350);
  };

  const handleRefreshAllApps = () => {
    setIsRefreshingAll(true);
    setTimeout(() => {
      setApps((prev) =>
        prev.map((item) => ({
          ...item,
          expiresInDays: 7,
          lastRefreshed: 'Just now'
        }))
      );
      setIsRefreshingAll(false);
      const distinctAccounts = new Set(apps.map((a) => a.accountAppleID)).size;
      setOperationBanner(
        `Refreshed all ${apps.length} installed apps across ${distinctAccounts} Apple IDs via AuthManager.performWithAccount() without losing active session.`
      );
    }, 500);
  };

  const handleInstallCatalogApp = (catalogItem: (typeof CATALOG_APPS)[number]) => {
    if (!activeAccount) return;
    const currentUsed = getAppIdsUsedForAccount(activeAccount.appleID);
    const maxSlots = activeAccount.teamType === 'Free' ? 10 : 100;
    if (currentUsed + catalogItem.appIdsRequired > maxSlots) {
      setOperationBanner(
        `Account ${activeAccount.appleID} has ${maxSlots - currentUsed} App ID slots left (needs ${catalogItem.appIdsRequired}). Switch to another Apple ID in Multi-Account Manager to sideload ${catalogItem.name}.`
      );
      return;
    }
    const existing = apps.find((a) => a.bundleId === catalogItem.bundleId);
    if (existing) {
      setOperationBanner(`${catalogItem.name} is already installed under ${existing.accountAppleID}.`);
      return;
    }
    const newApp: InstalledApp = {
      id: `app-${Date.now()}`,
      name: catalogItem.name,
      bundleId: catalogItem.bundleId,
      version: catalogItem.version,
      accountAppleID: activeAccount.appleID,
      teamId: activeAccount.teamId,
      expiresInDays: 7,
      appIdsUsed: catalogItem.appIdsRequired,
      lastRefreshed: 'Just now',
      category: catalogItem.category
    };
    setApps((prev) => [...prev, newApp]);
    setOperationBanner(
      `Installed ${catalogItem.name} signed with ${activeAccount.appleID} (${currentUsed + catalogItem.appIdsRequired}/${maxSlots} App IDs used on this account).`
    );
  };

  const handleCopyContent = (pathKey: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedPath(pathKey);
    setTimeout(() => setCopiedPath(null), 1800);
  };

  const handleDownloadFile = (filename: string, content: string) => {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename.split('/').pop() || filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  const filteredRepoFiles = useMemo(() => {
    if (!fileSearchQuery.trim()) return repoFiles;
    const q = fileSearchQuery.toLowerCase();
    return repoFiles.filter(
      (f) =>
        f.path.toLowerCase().includes(q) ||
        f.category.toLowerCase().includes(q) ||
        f.summary.toLowerCase().includes(q)
    );
  }, [repoFiles, fileSearchQuery]);

  const currentFile = useMemo(
    () => repoFiles.find((f) => f.path === selectedFilePath) || repoFiles[0],
    [repoFiles, selectedFilePath]
  );

  const totalAppIdsCapacity = accounts.reduce(
    (sum, acc) => sum + (acc.teamType === 'Free' ? 10 : 100),
    0
  );
  const totalAppIdsUsed = accounts.reduce(
    (sum, acc) => sum + getAppIdsUsedForAccount(acc.appleID),
    0
  );

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      {/* Top Bar Contract: Zone 1 Brand | Zone 2 Nav Links | Zone 3 Primary Action */}
      <header className="flex items-center justify-between gap-8 px-6 py-4 border-b border-slate-800/80 bg-slate-950/90 backdrop-blur-md sticky top-0 z-30">
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault();
            setActiveSection('accounts');
          }}
          className="text-lg font-bold tracking-tight text-white whitespace-nowrap shrink-0 font-display"
        >
          SideStore Multi-Account
        </a>

        <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-400">
          <button
            type="button"
            onClick={() => setActiveSection('accounts')}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 pb-0.5 ${
              activeSection === 'accounts' ? 'text-white border-b-2 border-teal-400' : ''
            }`}
          >
            Accounts & Keychain
          </button>
          <button
            type="button"
            onClick={() => setActiveSection('apps')}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 pb-0.5 ${
              activeSection === 'apps' ? 'text-white border-b-2 border-teal-400' : ''
            }`}
          >
            My Apps & Slots
          </button>
          <button
            type="button"
            onClick={() => setActiveSection('workflow')}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 pb-0.5 ${
              activeSection === 'workflow' ? 'text-white border-b-2 border-teal-400' : ''
            }`}
          >
            GitHub IPA Builder
          </button>
          <button
            type="button"
            onClick={() => setActiveSection('code')}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 pb-0.5 ${
              activeSection === 'code' ? 'text-white border-b-2 border-teal-400' : ''
            }`}
          >
            Modified Swift & CI Files
          </button>
        </nav>

        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={handleRefreshAllApps}
            disabled={isRefreshingAll}
            className="px-4 py-2 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 flex items-center gap-2 cursor-pointer disabled:opacity-60"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshingAll ? 'animate-spin' : ''}`} />
            <span>{isRefreshingAll ? 'Refreshing All Apps...' : 'Refresh All Apps'}</span>
          </button>
        </div>
      </header>

      {/* Mobile section selector */}
      <div className="flex md:hidden items-center gap-1 p-2 bg-slate-900 border-b border-slate-800 overflow-x-auto">
        {(['accounts', 'apps', 'workflow', 'code'] as ActiveSection[]).map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setActiveSection(tab)}
            className={`px-3 py-1.5 text-xs font-medium rounded-md whitespace-nowrap shrink-0 transition-colors ${
              activeSection === tab
                ? 'bg-slate-800 text-teal-300'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            {tab === 'accounts' && 'Accounts'}
            {tab === 'apps' && 'Apps & Slots'}
            {tab === 'workflow' && 'IPA Workflow'}
            {tab === 'code' && 'Swift & CI Code'}
          </button>
        ))}
      </div>

      {/* Main Content Container (1440px baseline) */}
      <main className="flex-1 w-full max-w-7xl mx-auto px-6 py-8 space-y-8">
        {/* Top Summary Banner & Active Account Context */}
        <section className="border border-slate-800 bg-slate-900/60 rounded-xl p-6">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
            <div className="space-y-2 max-w-2xl">
              <div className="flex items-center gap-2 text-xs text-slate-400">
                <span>SideStore iOS Multi-Account Engine</span>
                <span aria-hidden="true">·</span>
                <span>Keychain & CertificateManager Isolated</span>
                <span aria-hidden="true">·</span>
                <span>GitHub Actions IPA Ready</span>
              </div>
              <h1 className="text-2xl sm:text-3xl font-bold text-white tracking-tight font-display">
                Multi-Account Apple ID Signing & Automated IPA Workflow
              </h1>
              <p className="text-sm text-slate-300 leading-relaxed">
                Switch seamlessly between multiple free or paid Apple IDs without revoking existing signing certificates, bypass the 10-App-ID free developer limit across accounts, and build downloadable <code className="text-teal-300 font-mono">SideStore.ipa</code> artifacts directly from GitHub Actions.
              </p>
            </div>

            {/* Key Quantitative Metrics */}
            <div className="grid grid-cols-3 gap-4 pt-4 lg:pt-0 border-t lg:border-t-0 lg:border-l border-slate-800 lg:pl-6 shrink-0">
              <div>
                <div className="text-xs text-slate-400">Saved Apple IDs</div>
                <div className="text-2xl font-bold text-white font-mono tabular-nums mt-1">
                  {accounts.length}
                </div>
                <div className="text-xs text-slate-400 mt-0.5">Active: {activeAccount?.firstName}</div>
              </div>
              <div>
                <div className="text-xs text-slate-400">Combined App IDs</div>
                <div className="text-2xl font-bold text-teal-300 font-mono tabular-nums mt-1">
                  {totalAppIdsUsed}/{totalAppIdsCapacity}
                </div>
                <div className="text-xs text-slate-400 mt-0.5">10 per Free Apple ID</div>
              </div>
              <div>
                <div className="text-xs text-slate-400">Modified Files</div>
                <div className="text-2xl font-bold text-white font-mono tabular-nums mt-1">
                  {repoFiles.length || 9}
                </div>
                <div className="text-xs text-slate-400 mt-0.5">Swift + CI Workflows</div>
              </div>
            </div>
          </div>

          {operationBanner && (
            <div className="mt-5 pt-4 border-t border-slate-800/80 flex items-center justify-between gap-4 text-xs text-teal-200">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-teal-400 shrink-0" />
                <span>{operationBanner}</span>
              </div>
              <button
                type="button"
                onClick={() => setOperationBanner(null)}
                className="text-slate-400 hover:text-white whitespace-nowrap shrink-0 cursor-pointer"
              >
                Dismiss
              </button>
            </div>
          )}
        </section>

        {/* SECTION 1: ACCOUNTS & KEYCHAIN */}
        {activeSection === 'accounts' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            {/* Saved Accounts List */}
            <div className="lg:col-span-8 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-white font-display">
                    Saved Apple IDs in Keychain.savedAccounts
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Each account preserves its own <code className="font-mono">adsid</code>, <code className="font-mono">xcodeToken</code>, Team ID, and P12 signing certificate across switches.
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={handleImportSampleAccount}
                    className="px-3 py-2 text-xs font-medium text-slate-200 bg-slate-900 border border-slate-700 rounded-lg hover:bg-slate-800 transition-colors whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer"
                  >
                    <Upload className="w-3.5 h-3.5" />
                    <span>Import Account JSON</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowAddAccount((prev) => !prev)}
                    className="px-3 py-2 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Another Apple ID</span>
                  </button>
                </div>
              </div>

              {showAddAccount && (
                <form
                  onSubmit={handleAddAccount}
                  className="border border-slate-700 bg-slate-900 rounded-xl p-5 space-y-4"
                >
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold text-white">
                      Add Secondary Apple ID to Keychain
                    </h3>
                    <button
                      type="button"
                      onClick={() => setShowAddAccount(false)}
                      className="text-xs text-slate-400 hover:text-white"
                    >
                      Cancel
                    </button>
                  </div>
                  {formError && (
                    <div className="text-xs text-red-400 flex items-center gap-1.5">
                      <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                      <span>{formError}</span>
                    </div>
                  )}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                      <label className="block text-xs text-slate-400 mb-1">Apple ID Email</label>
                      <input
                        type="email"
                        required
                        placeholder="second.account@icloud.com"
                        value={newAppleID}
                        onChange={(e) => setNewAppleID(e.target.value)}
                        className="w-full px-3 py-2 text-sm bg-slate-950 border border-slate-800 rounded-lg text-white focus:outline-none focus:border-teal-400"
                      />
                    </div>
                    <div>
                      <label className="block text-xs text-slate-400 mb-1">First Name</label>
                      <input
                        type="text"
                        placeholder="Alex"
                        value={newFirstName}
                        onChange={(e) => setNewFirstName(e.target.value)}
                        className="w-full px-3 py-2 text-sm bg-slate-950 border border-slate-800 rounded-lg text-white focus:outline-none focus:border-teal-400"
                      />
                    </div>
                    <div>
                      <label className="block text-xs text-slate-400 mb-1">Developer Team Type</label>
                      <select
                        value={newTeamType}
                        onChange={(e) => setNewTeamType(e.target.value as 'Free' | 'Individual')}
                        className="w-full px-3 py-2 text-sm bg-slate-950 border border-slate-800 rounded-lg text-white focus:outline-none focus:border-teal-400"
                      >
                        <option value="Free">Free Personal Team (10 App IDs)</option>
                        <option value="Individual">Paid Individual Team (Unlimited)</option>
                      </select>
                    </div>
                  </div>
                  <div className="flex justify-end gap-2">
                    <button
                      type="submit"
                      className="px-4 py-2 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      Authenticate & Save Account
                    </button>
                  </div>
                </form>
              )}

              <div className="divide-y divide-slate-800 border border-slate-800 rounded-xl bg-slate-900/40 overflow-hidden">
                {accounts.map((acc) => {
                  const isCurrent = acc.appleID.toLowerCase() === activeAccount?.appleID.toLowerCase();
                  const usedSlots = getAppIdsUsedForAccount(acc.appleID);
                  const maxSlots = acc.teamType === 'Free' ? 10 : 100;
                  const accountApps = apps.filter(
                    (a) => a.accountAppleID.toLowerCase() === acc.appleID.toLowerCase()
                  );

                  return (
                    <div
                      key={acc.identifier}
                      className={`p-5 transition-colors ${
                        isCurrent ? 'bg-slate-900/90' : 'hover:bg-slate-900/50'
                      }`}
                    >
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <span className="text-base font-semibold text-white">
                              {acc.firstName} {acc.lastName}
                            </span>
                            <span className="text-xs text-slate-500" aria-hidden="true">·</span>
                            <span className="text-xs font-mono text-slate-300">{acc.appleID}</span>
                            {isCurrent && (
                              <>
                                <span className="text-xs text-slate-500" aria-hidden="true">·</span>
                                <span className="text-xs font-semibold text-teal-400">
                                  Active Signing Session
                                </span>
                              </>
                            )}
                          </div>

                          <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400 font-mono tabular-nums">
                            <span>Team: {acc.teamId} ({acc.teamType})</span>
                            <span aria-hidden="true">·</span>
                            <span>Cert Serial: {acc.certSerial}</span>
                            <span aria-hidden="true">·</span>
                            <span>App IDs: {usedSlots}/{maxSlots}</span>
                            <span aria-hidden="true">·</span>
                            <span>Installed Apps: {accountApps.length}</span>
                          </div>
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          {!isCurrent ? (
                            <button
                              type="button"
                              onClick={() => handleSwitchAccount(acc.appleID)}
                              className="px-3 py-1.5 text-xs font-medium text-white bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 transition-colors whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer"
                            >
                              <ArrowRightLeft className="w-3.5 h-3.5 text-teal-400" />
                              <span>Switch Active</span>
                            </button>
                          ) : (
                            <span className="px-3 py-1.5 text-xs font-medium text-teal-300 bg-teal-950/50 border border-teal-800/60 rounded-lg whitespace-nowrap shrink-0 flex items-center gap-1.5">
                              <Check className="w-3.5 h-3.5" />
                              <span>Selected</span>
                            </span>
                          )}

                          <button
                            type="button"
                            onClick={() => handleExportAccountJson(acc)}
                            title="Export StoredAccountCredentials JSON"
                            className="p-2 text-slate-400 hover:text-white bg-slate-900 border border-slate-800 rounded-lg transition-colors cursor-pointer"
                          >
                            <Download className="w-3.5 h-3.5" />
                          </button>

                          <button
                            type="button"
                            onClick={() => handleRemoveAccount(acc.appleID)}
                            title="Remove Account from Keychain"
                            className="p-2 text-slate-400 hover:text-red-400 bg-slate-900 border border-slate-800 rounded-lg transition-colors cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Right Column: Active Keychain & Certificate Architecture */}
            <div className="lg:col-span-4 border border-slate-800 bg-slate-900/50 rounded-xl p-5 space-y-5">
              <div>
                <h3 className="text-base font-semibold text-white font-display">
                  Active Keychain Session Inspector
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Mirrors <code className="font-mono">Keychain.shared</code> & <code className="font-mono">AuthManager.shared.activeAccount</code> state.
                </p>
              </div>

              {activeAccount && (
                <div className="space-y-3 text-xs border-t border-slate-800 pt-4">
                  <div className="flex justify-between py-1 border-b border-slate-800/60">
                    <span className="text-slate-400">appleIDEmailAddress</span>
                    <span className="font-mono text-white">{activeAccount.appleID}</span>
                  </div>
                  <div className="flex justify-between py-1 border-b border-slate-800/60">
                    <span className="text-slate-400">appleIDIdentifier</span>
                    <span className="font-mono text-slate-200 tabular-nums">{activeAccount.identifier}</span>
                  </div>
                  <div className="flex justify-between py-1 border-b border-slate-800/60">
                    <span className="text-slate-400">activeTeamIdentifier</span>
                    <span className="font-mono text-teal-300 tabular-nums">{activeAccount.teamId}</span>
                  </div>
                  <div className="flex justify-between py-1 border-b border-slate-800/60">
                    <span className="text-slate-400">signingCertificateSerialNumber</span>
                    <span className="font-mono text-slate-200 tabular-nums">{activeAccount.certSerial}</span>
                  </div>
                  <div className="flex justify-between py-1 border-b border-slate-800/60">
                    <span className="text-slate-400">isCurrentDeviceRegistered</span>
                    <span className="font-mono text-emerald-400">
                      {activeAccount.deviceRegistered ? 'true' : 'false'}
                    </span>
                  </div>
                  <div className="flex justify-between py-1">
                    <span className="text-slate-400">savedAccounts.count</span>
                    <span className="font-mono text-white tabular-nums">{accounts.length}</span>
                  </div>
                </div>
              )}

              <div className="border-t border-slate-800 pt-4 space-y-2">
                <div className="text-xs font-semibold text-slate-200">
                  How Multi-Account Avoids Breaking Existing Code
                </div>
                <ul className="space-y-2 text-xs text-slate-400 leading-relaxed">
                  <li>
                    1. All existing callers (<code className="font-mono text-slate-300">InstallAppOperation</code>, <code className="font-mono text-slate-300">VerifyAppOperation</code>) still read <code className="font-mono text-slate-300">AuthManager.shared.activeAccount</code> and <code className="font-mono text-slate-300">Keychain.shared</code> without signature changes.
                  </li>
                  <li>
                    2. Switching accounts swaps the active Keychain fields from <code className="font-mono text-slate-300">Keychain.shared.savedAccounts</code> and restores the matching P12 certificate in <code className="font-mono text-slate-300">CertificateManager</code>.
                  </li>
                  <li>
                    3. <code className="font-mono text-slate-300">RefreshAppOperation</code> uses <code className="font-mono text-slate-300">performWithAccount(appleID:)</code> to temporarily bind each app's owning Apple ID during background refresh.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        )}

        {/* SECTION 2: MY APPS & PER-ACCOUNT SLOTS */}
        {activeSection === 'apps' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            <div className="lg:col-span-8 space-y-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-white font-display">
                    Installed Apps Across All Saved Apple IDs
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Refreshing an app automatically authenticates with the Apple ID that originally signed it.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={handleRefreshAllApps}
                  disabled={isRefreshingAll}
                  className="px-3.5 py-2 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  {isRefreshingAll ? 'Refreshing...' : 'Refresh All (Multi-Account)'}
                </button>
              </div>

              <div className="border border-slate-800 rounded-xl overflow-hidden bg-slate-900/40">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-slate-800 text-xs text-slate-400 bg-slate-900/80">
                      <th className="py-3 px-4 font-medium">Application</th>
                      <th className="py-3 px-4 font-medium">Signing Apple ID</th>
                      <th className="py-3 px-4 font-medium text-right">App IDs</th>
                      <th className="py-3 px-4 font-medium text-right">Validity</th>
                      <th className="py-3 px-4 font-medium text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/70 text-sm">
                    {apps.map((app) => (
                      <tr key={app.id} className="hover:bg-slate-900/60 transition-colors">
                        <td className="py-3.5 px-4">
                          <div className="font-medium text-white">{app.name}</div>
                          <div className="text-xs text-slate-400 font-mono">
                            {app.bundleId} · v{app.version}
                          </div>
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="text-xs font-mono text-slate-200">{app.accountAppleID}</div>
                          <div className="text-xs text-slate-500 font-mono">Team {app.teamId}</div>
                        </td>
                        <td className="py-3.5 px-4 text-right font-mono tabular-nums text-xs text-slate-300">
                          {app.appIdsUsed} slots
                        </td>
                        <td className="py-3.5 px-4 text-right font-mono tabular-nums text-xs">
                          <span className="text-emerald-400">{app.expiresInDays} days</span>
                          <div className="text-slate-500">{app.lastRefreshed}</div>
                        </td>
                        <td className="py-3.5 px-4 text-right">
                          <button
                            type="button"
                            onClick={() => handleRefreshSingleApp(app)}
                            disabled={refreshingAppId === app.id}
                            className="px-3 py-1.5 text-xs font-medium text-slate-200 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                          >
                            {refreshingAppId === app.id ? 'Signing...' : 'Refresh'}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Sideload Catalog using Active Account */}
            <div className="lg:col-span-4 border border-slate-800 bg-slate-900/50 rounded-xl p-5 space-y-4">
              <div>
                <h3 className="text-base font-semibold text-white font-display">
                  Sideload with Active Account
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Currently signing new apps with <span className="font-mono text-teal-300">{activeAccount?.appleID}</span> ({getAppIdsUsedForAccount(activeAccount?.appleID || '')}/10 App IDs used).
                </p>
              </div>

              <div className="divide-y divide-slate-800 border-t border-slate-800">
                {CATALOG_APPS.map((item) => (
                  <div key={item.bundleId} className="py-3.5 flex items-center justify-between gap-3">
                    <div>
                      <div className="text-sm font-medium text-white">{item.name}</div>
                      <div className="text-xs text-slate-400 font-mono tabular-nums">
                        {item.category} · {item.appIdsRequired} App IDs
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleInstallCatalogApp(item)}
                      className="px-3 py-1.5 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      Install
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* SECTION 3: GITHUB ACTIONS IPA BUILDER */}
        {activeSection === 'workflow' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            <div className="lg:col-span-7 space-y-6">
              <div className="border border-slate-800 bg-slate-900/50 rounded-xl p-6 space-y-4">
                <div>
                  <h2 className="text-lg font-semibold text-white font-display">
                    GitHub Actions <code className="font-mono text-teal-300">SideStore.ipa</code> Build Pipeline
                  </h2>
                  <p className="text-xs text-slate-400 mt-1">
                    Adjusted <code className="font-mono">.github/workflows/pr.yml</code>, <code className="font-mono">nightly.yml</code>, and <code className="font-mono">attach_build_products.yml</code> so your fork or repository builds and uploads an installable <code className="font-mono">.ipa</code> file on any push, pull request, or manual click.
                  </p>
                </div>

                {/* Trigger Simulator Controls */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Workflow Trigger Event</label>
                    <select
                      value={selectedTrigger}
                      onChange={(e) =>
                        setSelectedTrigger(e.target.value as 'workflow_dispatch' | 'push' | 'pull_request')
                      }
                      className="w-full px-3 py-2 text-xs font-mono bg-slate-950 border border-slate-800 rounded-lg text-white"
                    >
                      <option value="workflow_dispatch">workflow_dispatch (Manual Run)</option>
                      <option value="push">push (main / master / develop / feat/**)</option>
                      <option value="pull_request">pull_request (Opened / Synchronize)</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Target Branch</label>
                    <input
                      type="text"
                      value={selectedBranch}
                      onChange={(e) => setSelectedBranch(e.target.value)}
                      className="w-full px-3 py-2 text-xs font-mono bg-slate-950 border border-slate-800 rounded-lg text-white"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Xcode Configuration</label>
                    <select
                      value={buildConfig}
                      onChange={(e) => setBuildConfig(e.target.value as 'Release' | 'Debug')}
                      className="w-full px-3 py-2 text-xs font-mono bg-slate-950 border border-slate-800 rounded-lg text-white"
                    >
                      <option value="Release">Release (SideStore.ipa)</option>
                      <option value="Debug">Debug (SideStore.ipa)</option>
                    </select>
                  </div>
                </div>

                {/* Step-by-Step Pipeline Breakdown */}
                <div className="divide-y divide-slate-800 border border-slate-800 rounded-xl bg-slate-950/70">
                  <div className="p-4 flex items-start justify-between gap-4">
                    <div>
                      <div className="text-xs font-semibold text-white">
                        01. Checkout Submodules & Fetch Prebuilt Binaries
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Runs <code className="font-mono">actions/checkout@v4</code> with <code className="font-mono">submodules: recursive</code> and downloads <code className="font-mono">minimuxer</code> and <code className="font-mono">em_proxy</code> static libraries.
                      </p>
                    </div>
                    <span className="text-xs font-mono text-emerald-400 shrink-0">macos-15 / Xcode 16.4</span>
                  </div>

                  <div className="p-4 flex items-start justify-between gap-4">
                    <div>
                      <div className="text-xs font-semibold text-white">
                        02. Multi-Event Version Resolution
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Automatically computes <code className="font-mono">VERSION</code> whether triggered via <code className="font-mono">{selectedTrigger}</code> on branch <code className="font-mono">{selectedBranch}</code> (no longer crashes when <code className="font-mono">github.event.pull_request.number</code> is empty).
                      </p>
                    </div>
                    <span className="text-xs font-mono text-teal-300 shrink-0">
                      SideStore-0.6.3-{selectedBranch}.ipa
                    </span>
                  </div>

                  <div className="p-4 flex items-start justify-between gap-4">
                    <div>
                      <div className="text-xs font-semibold text-white">
                        03. Archive & Package Unsigned IPA (<code className="font-mono">workflow.py build -c {buildConfig}</code>)
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Compiles <code className="font-mono">SideStore</code> scheme with <code className="font-mono">CODE_SIGNING_ALLOWED=NO</code>, packages <code className="font-mono">Payload/SideStore.app</code> into <code className="font-mono">SideStore.ipa</code>, and uploads via <code className="font-mono">actions/upload-artifact@v4</code>.
                      </p>
                    </div>
                    <span className="text-xs font-mono text-emerald-400 shrink-0">Artifact Uploaded</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Instructions to Run on GitHub */}
            <div className="lg:col-span-5 border border-slate-800 bg-slate-900/50 rounded-xl p-6 space-y-4">
              <h3 className="text-base font-semibold text-white font-display">
                How to Get Your Built <code className="font-mono text-teal-300">.ipa</code> on GitHub
              </h3>
              <ol className="space-y-3 text-xs text-slate-300 leading-relaxed">
                <li>
                  <strong className="text-white">1. Push to your GitHub repo:</strong> Push the updated Swift and <code className="font-mono">.github/workflows/</code> files to <code className="font-mono">main</code>, <code className="font-mono">develop</code>, or any branch.
                </li>
                <li>
                  <strong className="text-white">2. Automatic or Manual Trigger:</strong> Open the <strong className="text-white">Actions</strong> tab in your GitHub repository, select <strong className="text-white">Pull Request SideStore build</strong> (or <strong className="text-white">Nightly SideStore deployment</strong>), and click <strong className="text-white">Run workflow</strong>.
                </li>
                <li>
                  <strong className="text-white">3. Download Artifact:</strong> Once the macOS runner completes, scroll to the <strong className="text-white">Artifacts</strong> section on the workflow summary page and download <strong className="text-teal-300 font-mono">SideStore-ipa</strong> (or the direct <code className="font-mono">SideStore-&lt;version&gt;.ipa</code> file).
                </li>
              </ol>

              <div className="pt-2 flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setSelectedFilePath('.github/workflows/pr.yml');
                    setActiveSection('code');
                  }}
                  className="px-3.5 py-2 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  Inspect .github/workflows/pr.yml
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedFilePath('.github/workflows/nightly.yml');
                    setActiveSection('code');
                  }}
                  className="px-3.5 py-2 text-xs font-medium text-slate-200 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  Inspect .github/workflows/nightly.yml
                </button>
              </div>
            </div>
          </div>
        )}

        {/* SECTION 4: MODIFIED SWIFT & CI FILES INSPECTOR */}
        {activeSection === 'code' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* File Sidebar */}
            <div className="lg:col-span-4 border border-slate-800 bg-slate-900/50 rounded-xl p-4 space-y-3">
              <div className="relative">
                <Search className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Filter Swift or workflow files..."
                  value={fileSearchQuery}
                  onChange={(e) => setFileSearchQuery(e.target.value)}
                  className="w-full pl-8 pr-3 py-1.5 text-xs bg-slate-950 border border-slate-800 rounded-lg text-white focus:outline-none focus:border-teal-400"
                />
              </div>

              <div className="divide-y divide-slate-800/70 max-h-[540px] overflow-y-auto">
                {filteredRepoFiles.map((file) => {
                  const isSelected = file.path === currentFile?.path;
                  return (
                    <button
                      key={file.path}
                      type="button"
                      onClick={() => setSelectedFilePath(file.path)}
                      className={`w-full text-left p-3 transition-colors cursor-pointer ${
                        isSelected ? 'bg-slate-800/90' : 'hover:bg-slate-900'
                      }`}
                    >
                      <div className="text-xs font-mono font-semibold text-white truncate">
                        {file.path.split('/').pop()}
                      </div>
                      <div className="text-[11px] font-mono text-slate-400 truncate mt-0.5">
                        {file.path}
                      </div>
                      <div className="text-[11px] text-slate-400 mt-1 line-clamp-2">
                        {file.summary}
                      </div>
                      <div className="text-[11px] font-mono text-slate-500 tabular-nums mt-1">
                        {file.lines} lines · {(file.sizeBytes / 1024).toFixed(1)} KB
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Code Viewer */}
            <div className="lg:col-span-8 border border-slate-800 bg-slate-900/50 rounded-xl overflow-hidden">
              {currentFile ? (
                <>
                  <div className="p-4 border-b border-slate-800 flex flex-wrap items-center justify-between gap-4 bg-slate-900">
                    <div>
                      <div className="text-xs font-mono font-semibold text-teal-300">
                        {currentFile.path}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">{currentFile.summary}</div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      <button
                        type="button"
                        onClick={() => handleCopyContent(currentFile.path, currentFile.content)}
                        className="px-3 py-1.5 text-xs font-medium text-slate-200 bg-slate-800 border border-slate-700 rounded-lg hover:bg-slate-700 transition-colors whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer"
                      >
                        {copiedPath === currentFile.path ? (
                          <>
                            <Check className="w-3.5 h-3.5 text-teal-400" />
                            <span>Copied</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5" />
                            <span>Copy File</span>
                          </>
                        )}
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDownloadFile(currentFile.path, currentFile.content)}
                        className="px-3 py-1.5 text-xs font-semibold text-slate-950 bg-teal-400 rounded-lg hover:bg-teal-300 transition-colors whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer"
                      >
                        <Download className="w-3.5 h-3.5" />
                        <span>Download</span>
                      </button>
                    </div>
                  </div>
                  <pre className="p-4 text-xs font-mono text-slate-200 overflow-x-auto max-h-[560px] overflow-y-auto leading-relaxed bg-slate-950">
                    <code>{currentFile.content}</code>
                  </pre>
                </>
              ) : (
                <div className="p-8 text-center text-sm text-slate-400">
                  Select a file on the left to inspect its implementation.
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      <footer className="border-t border-slate-900 py-5 px-6 text-xs text-slate-500">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <span>SideStore Multi-Account & GitHub Actions IPA Workspace</span>
          <span>Native iOS Swift codebase and GitHub Actions workflows preserved in repository root</span>
        </div>
      </footer>
    </div>
  );
}
