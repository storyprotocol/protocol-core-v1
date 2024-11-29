import "../setup";
import { expect } from "chai";

describe("License", function () {
  it("license", async function () {
    const name = await this.licensingModule.name();
    expect(name).to.equal("LICENSING_MODULE");
  });
})