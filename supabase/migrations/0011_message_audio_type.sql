-- Voice messages insert with type 'audio'; add it to the enum.
alter type message_type add value if not exists 'audio';
