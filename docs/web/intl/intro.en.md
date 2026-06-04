# ShrimpSend Key Features

**Region**: International service cluster, for example `api.shrimpsend.com` / `ws.shrimpsend.com`.

ShrimpSend is a message and file sending tool for your own devices. It is not a cloud drive and it is not a traditional "upload, create a link, send the link to yourself" workflow. It is closer to a private conversation between your phone, desktop, and browser: choose a target device, then send text, clipboard snippets, images, videos, and large files directly to it.

## Why ShrimpSend exists

Modern workflows often involve too many devices: phone, laptop, desktop, tablet, work computer, and temporary browsers. The most common needs are small, frequent, and repetitive:

- Move a phone screenshot to a computer.
- Send an installer from one desktop to another.
- Move a copied browser snippet to a phone.
- When installing a client is impractical (work PC, guest device), a browser is enough; on the same LAN, browser-to-browser transfer can still use a direct path.
- Send a large file to another device on the same Wi-Fi.
- Continue a large transfer after interruption instead of starting over.
- On the same LAN, Android-to-Windows transfers are often one-way: Windows firewalls commonly block inbound connections, so your phone can push to the PC while the PC cannot push back.
- Home networks are not always one flat subnet: one device on Ethernet and another on Wi-Fi or behind a secondary router may sit on different segments or NAT layers, so "same network" does not guarantee bidirectional reachability.
- Fall back to a reliable path when LAN transfer is unavailable.

ShrimpSend is designed to remove friction from those everyday device-to-device sends.

## Core model: device conversations

ShrimpSend is device-centered. You do not create a public link first; you send content into a selected device conversation. That makes repeated sends natural: a note, a few images, a ZIP file, and a video can all live in the same device conversation.

## Main features

### Text and clipboard sending

Not every transfer deserves a cloud drive or a chat app. Config snippets, links, commands, temporary notes, verification instructions, and short text can go straight into a device conversation.

### Files and large-file sending

ShrimpSend supports images, videos, archives, installers, and project files. Large files are usually best sent over direct LAN paths when devices are nearby. If a native-client transfer is interrupted, it can resume from the interrupted position instead of restarting from zero.

### LAN first

When devices are on the same network, ShrimpSend prefers LAN / WebRTC style paths. For frequent sends and large files, this is often more natural than relaying everything through the public internet.

### S3 fallback

S3 is a fallback path, not a replacement for LAN. When direct transfer is unavailable, devices are across networks, or the network is constrained, hosted object storage or custom S3 keeps the file deliverable.

### Web participation

The web app is useful for temporary access. On a computer without the native client installed, open the browser and join your device conversation to send or receive content.

## Product comparison

Different transfer tools solve different problems. ShrimpSend focuses on frequent text and file sends across your own devices, not one-off public sharing or LAN-only transfer.

| Product | Strengths | Limitations | Best fit |
| --- | --- | --- | --- |
| ShrimpSend | Device conversation model for repeated text, clipboard, and file sends; LAN / WebRTC first on the same network; native-client resume for interrupted transfers; hosted or custom S3 fallback when direct transfer is unavailable; web app can temporarily join. | Full experience requires native clients; web app is limited by browser capabilities; some enhanced paths require sign-in. | Frequent sends across your own phone, desktop, and browser; same-network large files; cross-network fallback when direct paths fail. |
| WeTransfer | No client installation required for both sides; easy one-off delivery to other people; recipients download through a link. | Primarily upload-to-cloud and link-sharing; not optimized for repeated sends among your own devices; large files rely on public internet and platform storage; LAN direct transfer is not the core model. | Sending files to clients, teammates, or temporary external recipients. |
| LocalSend | Open source, LAN-first, no account required; simple and direct when devices are on the same network. | Depends on LAN reachability; cross-network, complex NAT, web participation, and fallback paths are not the focus; weaker device-conversation experience for repeated text and file sends. | Home or office Wi-Fi where every device has the client installed and the network is reachable. |
| Cloud drives | Strong file management, long-term storage, folders, and multi-person sharing. | Heavier upload, organization, and sharing workflow; not lightweight for temporary text and small files; LAN direct transfer and send-to-device flows are not core. | Long-term storage, team document management, and shared folders. |
| Chat app file assistants | Already familiar; good for quick text, images, and small files. | Usually no multi-device simultaneous login on the same platform (e.g. Android may allow only one active session at a time), making cross-device sync unreliable; file size, format, compression, and retention may be limited; large-file resume, LAN direct transfer, and device management are not the focus. | Lightweight text, small images, and small temporary files. |

## How to choose

- Use WeTransfer or a cloud drive when sending files to people outside your own devices.
- Use LocalSend when all devices are on the same LAN, clients are installed, and you only need occasional transfers.
- Use ShrimpSend when you repeatedly send text, screenshots, installers, videos, and large files across your own devices, and you want LAN-first transfer plus a reliable fallback path.
- Use a cloud drive when long-term organization and archival are more important than fast device-to-device sending.

## Sign-in and no-sign-in transfer

Native clients can transfer on the same LAN without signing in. Signing in lets the web app join your device conversation, syncs device and subscription state, and enables server-assisted discovery in one-way firewall or NAT situations.

## Text message cloud storage and encryption

When text messages are synced through our servers (for example while signed in or when fetching history across networks), we apply the following policy to text stored in the cloud:

- **Only the text body is encrypted**: we encrypt the message body of text-type messages at rest on the server. Metadata such as message type, timestamp, device information, and conversation identifiers remain readable so sync and operations can work normally.
- **File messages stay readable**: metadata for file messages (such as file name, storage location, and size) is not encrypted the same way, so object lifecycle cleanup and management remain possible.
- **Local storage is not encrypted**: text cached on your device stays in plaintext so you can read it offline and search locally.
- **No cloud search**: we do not run keyword search over message bodies on the server. Search is limited to messages already cached on your device.

Text sent only over LAN direct transfer is not written to the cloud database and is therefore outside this cloud-storage encryption policy.

## International cluster

The international cluster uses international legal documents, payment channels, subscription plans, and hosted storage rules. Membership is usually billed as USD subscriptions through Apple, Google Play, Stripe, or RevenueCat.
