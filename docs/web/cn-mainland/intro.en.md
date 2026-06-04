# ShrimpSend Key Features (Mainland China)

**Region**: Mainland China service cluster, for example `api.xiachuan.net` / `ws.xiachuan.net`.

ShrimpSend is a message and file sending tool for your own devices. It is not a cloud drive and it is not a traditional "upload a file, create a link, then send the link to yourself" sharing tool. Its goal is simple: when you have multiple devices nearby, you can send text, clipboard snippets, screenshots, videos, installers, and large files directly to a target device, much like sending a message in a chat window.

## Why ShrimpSend exists

Many people now use phones, tablets, laptops, desktops, work computers, and temporary browsers at the same time. The more devices you have, the more often you need to move something from device A to device B:

- Move a screenshot from your phone to a computer for editing.
- Send an installer from one computer to a nearby Windows device.
- Move copied browser text to your phone immediately.
- When installing a client is impractical (work PC, guest device), a browser is enough; on the same LAN, browser-to-browser transfer can still use a direct path.
- Resume a large transfer after interruption instead of starting over.
- Use a direct LAN path when two devices are on the same network, instead of routing through a cloud drive.
- On the same LAN, Android-to-Windows transfers are often one-way: Windows firewalls commonly block inbound connections, so your phone can push to the PC while the PC cannot push back.
- Home networks are not always one flat subnet: one device on Ethernet and another on Wi-Fi or behind a secondary router may sit on different segments or NAT layers, so "same network" does not guarantee bidirectional reachability.
- Still deliver files when direct connection fails in corporate networks, campus networks, or complex NAT environments.

ShrimpSend is designed for these frequent, small, and real cross-device sending workflows.

## Core interaction: device conversations

ShrimpSend is centered on device conversations, not file links. You choose a target device and send content into that conversation. To the user, it feels more like sending a message to another one of your own devices.

This model is built for repeated sends: send a text note, then a few images, then an archive, without creating a sharing link, copying it, and opening it again every time.

## Main features

### Text, clipboard, and temporary content

Many cross-device needs are not formal file transfers. They are temporary snippets: a link, a configuration value, verification instructions, a command, or short text. ShrimpSend keeps these messages and files in the same conversation so you do not have to jump between chat apps, notes, and cloud drives.

### Files and large-file sending

ShrimpSend supports images, videos, installers, archives, and project files. For large files on the same LAN, local transfer is usually more suitable than public internet routing. If a native-client transfer is interrupted, it can resume from the interrupted position instead of restarting from zero.

### LAN first

When devices are on the same LAN, ShrimpSend prefers direct LAN or WebRTC-style paths. This reduces unnecessary public-network routing and works better for frequent sends and large files.

### S3 fallback

S3 is not a replacement for LAN transfer and is not the preferred path for large files by default. It is a fallback for cases where LAN is unavailable: devices are across networks, direct connection fails, or the network is constrained. In those situations, S3 can act as a backup channel so files can still be delivered.

### Web participation

In addition to native clients, the web app can join device conversations. When you temporarily use someone else's computer, a work computer, or a browser-only environment, you can open the web app to send and receive content without installing a client.

## Product comparison

Different transfer tools solve different problems. ShrimpSend focuses on frequent text and file sends across your own devices, not one-off public sharing or LAN-only transfer.

| Product | Strengths | Limitations | Best fit |
| --- | --- | --- | --- |
| ShrimpSend | Device conversation model for repeated text, clipboard, and file sends; LAN / WebRTC first on the same network; native-client resume for interrupted transfers; S3 fallback when direct transfer is unavailable; web app can temporarily join. | Full experience requires native clients; web app is limited by browser capabilities; some enhanced paths require sign-in. | Frequent sends across your own phone, desktop, and browser; same-network large files; cross-network fallback when direct paths fail. |
| WeTransfer | No client installation required for both sides; easy one-off delivery to other people; recipients download through a link. | Primarily upload-to-cloud and link-sharing; not optimized for repeated sends among your own devices; large files rely on public internet and platform storage; LAN direct transfer is not the core model. | Sending files to clients, teammates, or temporary external recipients. |
| LocalSend | Open source, LAN-first, no account required; simple and direct when devices are on the same network. | Depends on LAN reachability; cross-network, complex NAT, web participation, and fallback paths are not the focus; weaker device-conversation experience for repeated text and file sends. | Home or office Wi-Fi where every device has the client installed and the network is reachable. |
| Cloud drives | Strong file management, long-term storage, folders, and multi-person sharing. | Heavier upload, organization, and sharing workflow; not lightweight for temporary text and small files; LAN direct transfer and resume-to-device flows are not core. | Long-term storage, team document management, and shared folders. |
| Chat app file assistants | Familiar and convenient for quick text, images, and small files. | Usually no multi-device simultaneous login on the same platform (e.g. Android may allow only one active session at a time), making cross-device sync unreliable; file size, format, compression, and retention may be limited; large-file resume, LAN direct transfer, and device management are not the focus. | Lightweight text, small images, and small temporary files. |

## How to choose

- Use WeTransfer or a cloud drive when sending files to people outside your own devices.
- Use LocalSend when all devices are on the same LAN, clients are installed, and you only need occasional transfers.
- Use ShrimpSend when you repeatedly send text, screenshots, installers, videos, and large files across your own devices, and you want LAN-first transfer plus a reliable fallback path.
- Use a cloud drive when long-term organization and archival matter more than fast device-to-device sending.

## Sign-in and no-sign-in transfer

Native clients can discover and transfer on the same LAN without signing in. Signing in is not meant to force LAN traffic through the server. It lets the web app join your device conversations, syncs your device list, and helps with server-assisted discovery in one-way firewall or NAT situations.

## Text message cloud storage and encryption

When text messages are synced through our servers (for example while signed in or when fetching history across networks), we apply the following policy to text stored in the cloud:

- **Only the text body is encrypted**: we encrypt the message body of text-type messages at rest on the server. Metadata such as message type, timestamp, device information, and conversation identifiers remain readable so sync and operations can work normally.
- **File messages stay readable**: metadata for file messages (such as file name, storage location, and size) is not encrypted the same way, so object lifecycle cleanup and management remain possible.
- **Local storage is not encrypted**: text cached on your device stays in plaintext so you can read it offline and search locally.
- **No cloud search**: we do not run keyword search over message bodies on the server. Search is limited to messages already cached on your device.

Text sent only over LAN direct transfer is not written to the cloud database and is therefore outside this cloud-storage encryption policy.

## Mainland China service characteristics

The Mainland China service cluster is designed for users in Mainland China. Payment, legal documents, service operator information, and membership rules are shown according to the Mainland China version. Membership is currently priced as a one-time purchase in RMB; the final details are subject to the purchase page and payment order.
