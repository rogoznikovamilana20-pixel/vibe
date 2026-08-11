/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  // ---- profiles ---------------------------------------------------------
  const profiles = new Collection({
    name: "profiles",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });
  profiles.fields.add(new TextField({ name: "username", required: true }));
  profiles.fields.add(new TextField({ name: "displayName" }));
  profiles.fields.add(new TextField({ name: "emoji" }));
  profiles.fields.add(
    new FileField({
      name: "avatar",
      maxSelect: 1,
      maxSize: 5242880,
      mimeTypes: ["image/jpeg", "image/png", "image/webp"],
    })
  );
  profiles.fields.add(new BoolField({ name: "online" }));
  app.save(profiles);

  // ---- chats
  const chats = new Collection({
    name: "chats",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });
  chats.fields.add(new TextField({ name: "title" }));
  chats.fields.add(
    new SelectField({
      name: "kind",
      required: true,
      maxSelect: 1,
      values: ["pm", "group", "channel", "biz"],
    })
  );
  chats.fields.add(
    new RelationField({
      name: "members",
      maxSelect: 100,
      collectionId: profiles.id,
    })
  );
  app.save(chats);

  // ---- messages ---------------------------------------------------------
  const messages = new Collection({
    name: "messages",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });
  messages.fields.add(
    new RelationField({
      name: "chat",
      required: true,
      maxSelect: 1,
      collectionId: chats.id,
    })
  );
  messages.fields.add(
    new RelationField({
      name: "sender",
      required: true,
      maxSelect: 1,
      collectionId: profiles.id,
    })
  );
  messages.fields.add(new TextField({ name: "text" }));
  messages.fields.add(
    new FileField({
      name: "voice",
      maxSelect: 1,
      maxSize: 15728640,
      mimeTypes: [
        "audio/mp4",
        "audio/m4a",
        "audio/aac",
        "audio/mp3",
        "audio/ogg",
        "audio/wav",
        "audio/x-m4a",
      ],
    })
  );
  messages.fields.add(
    new FileField({
      name: "photo",
      maxSelect: 1,
      maxSize: 10485760,
      mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"],
    })
  );
  app.save(messages);
}, (app) => {
  const messages = app.findCollectionByNameOrId("messages");
  const chat = app.findCollectionByNameOrId("chats");
  const profiles = app.findCollectionByNameOrId("profiles");
  if (messages) app.delete(messages);
  if (chat) app.delete(chat);
  if (profiles) app.delete(profiles);
});