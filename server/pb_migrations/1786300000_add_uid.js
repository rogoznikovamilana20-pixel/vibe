/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("profiles");

  collection.fields.add(new NumberField({
    name: "uid",
    min: 10000000,
    max: 99999999,
  }));

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("profiles");

  collection.fields.removeByName("uid");

  return app.save(collection);
})
