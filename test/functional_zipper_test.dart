import 'package:test/test.dart';
import 'package:functional_zipper/functional_zipper.dart';

abstract class ZipperTree {}

class ZipperTreeItem extends ZipperTree {
  final int item;
  ZipperTreeItem(this.item);
}

class ZipperTreeSection extends ZipperTree {
  final List<ZipperTree> children;
  final String name;
  ZipperTreeSection(this.children, this.name);
}

typedef TreeZipper
    = ZipperLocation<ZipperTree, ZipperTreeItem, ZipperTreeSection>;

TreeZipper build() {
  return ZipperLocation.root(
    sectionP: (b) => b is ZipperTreeSection,
    getChildren: (ZipperTreeSection sec) => sec.children,
    makeSection: (ZipperTreeSection sec, List<ZipperTree> cs) =>
        ZipperTreeSection(cs, sec.name),
    node: ZipperTreeSection(
      List.unmodifiable([
        ZipperTreeItem(1),
        ZipperTreeItem(2),
        ZipperTreeSection(
          List.unmodifiable([
            ZipperTreeItem(3),
          ]),
          "offspring",
        ),
      ]),
      "root",
    ),
  );
}

void main() {
  test('navigation', () {
    TreeZipper loc = build();

    expect(() => loc.goLeft(), throwsA(isA<Exception>()));

    var res = loc.goDown();
    expect(res.node, isA<ZipperTreeItem>());
    expect((res.node as ZipperTreeItem).item, 1);

    expect(() => res.goLeft(), throwsA(isA<Exception>()));

    res = res.goRight();
    expect(res.node, isA<ZipperTreeItem>());
    expect((res.node as ZipperTreeItem).item, 2);

    expect(() => res.goRight().goRight(), throwsA(isA<Exception>()));

    res = res.goRight().goDown();
    expect(res.node, isA<ZipperTreeItem>());
    expect((res.node as ZipperTreeItem).item, 3);

    res = res.goUp();
    expect((res.node as ZipperTreeSection).name, "offspring");
    res = res.goLeft();
    expect(res.node, isA<ZipperTreeItem>());
    expect((res.node as ZipperTreeItem).item, 2);

    res = res.goUp();
    expect(res.path, isA<TopPath>());
    expect((res.node as ZipperTreeSection).name, "root");
  });

  test('modification', () {
    TreeZipper loc = build();

    expect(() => loc.delete(), throwsA(isA<Exception>()));

    var res = loc.goDown();
    expect((res.node as ZipperTreeItem).item, 1);

    var resl = res.insertRight(ZipperTreeItem(10));
    expect((res.goRight().node as ZipperTreeItem).item, 2);
    expect((resl.goRight().node as ZipperTreeItem).item, 10);

    res = res.goRight();
    expect(() => res.insertDown(ZipperTreeItem(42)), throwsA(isA<Exception>()));

    res = res.goRight().insertDown(ZipperTreeItem(42));
    expect((res.node as ZipperTreeItem).item, 42);

    res = res.goRight();
    expect((res.node as ZipperTreeItem).item, 3);

    res = res.delete();
    expect((res.node as ZipperTreeItem).item, 42);

    res = res.delete();
    expect(res.node, isA<ZipperTreeSection>());
    expect((res.node as ZipperTreeSection).children, isEmpty);
    expect((res.node as ZipperTreeSection).name, "offspring");

    res = res.delete();
    expect((res.node as ZipperTreeItem).item, 2);
  });
}
