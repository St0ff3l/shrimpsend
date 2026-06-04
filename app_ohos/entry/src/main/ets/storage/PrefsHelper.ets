import dataPreferences from '@ohos.data.preferences';
import { getAbilityContext } from '../common/AppContext';

const STORE_NAME = 'ultrasend_prefs';

async function getPrefs(): Promise<dataPreferences.Preferences> {
  return await dataPreferences.getPreferences(getAbilityContext(), STORE_NAME);
}

export async function prefGetString(key: string, defaultVal: string = ''): Promise<string> {
  const p = await getPrefs();
  const v = await p.get(key, defaultVal) as string;
  return v ?? defaultVal;
}

export async function prefSetString(key: string, value: string): Promise<void> {
  const p = await getPrefs();
  await p.put(key, value);
  await p.flush();
}

export async function prefRemove(key: string): Promise<void> {
  const p = await getPrefs();
  await p.delete(key);
  await p.flush();
}
