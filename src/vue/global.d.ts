export {};

declare global {
  interface Window {
    serverCall: (method: string, args: unknown[]) => Promise<string>;
    bloomCreateApp: (createApp: typeof import('vue').createApp) => import('vue').App<Element>;
  }
}
