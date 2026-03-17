## Plan: Minimal Pet Adoption Page

以**最小版本改动**为目标，建议把“领养”先做成一个轻量展示/标记功能：新增一个 `"Adopt Me"` 导航页，列出被标记为可领养的宠物，并在点击按钮后仅把该宠物改为“已领养/不可再领养”。这样可以避免引入新的主人绑定流程、独立 `Adoption` 实体或复杂服务层，只在现有 MVC + JPA 结构上做最少扩展。

### Steps
1. 在 [`Pet`](src/main/java/org/springframework/samples/petclinic/owner/Pet.java) 增加最小状态字段，如 `adoptable`，不引入独立 `Adoption` 模型。
2. 复用 [`OwnerRepository`](src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java) 的现有查询能力，在新控制器中聚合 `owner.pets`，避免新增 [`PetRepository`](src/main/java/org/springframework/samples/petclinic/owner)。
3. 新建 `AdoptionController`，提供 `GET /adoptions` 列表页和 `POST` 领养动作，只把目标宠物标记为不可领养。
4. 在 [`layout.html`](src/main/resources/templates/fragments/layout.html) 增加 `"Adopt Me"` 导航项，并新增一个简单列表页到 [`templates/pets/`](src/main/resources/templates/pets)。
5. 更新 [`messages.properties`](src/main/resources/messages/messages.properties) 和三套 [`db/*/schema.sql`](src/main/resources/db/h2/schema.sql) / `data.sql`，为 `pets` 增加领养字段和少量演示数据。

### Further Considerations
1. 最小版本建议选 Option A：点击按钮后仅标记“已领养”，暂不绑定新主人。
2. 列表展示建议仅含宠物名、类型、生日、当前主人姓名；先不加筛选、分页、申请表单。


