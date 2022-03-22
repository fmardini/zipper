import 'package:meta/meta.dart';

/// A more or less direct implementation of Huet's paper
/// Some inspiration from Clojure's zippers in an attemp to make it generic
/// The Dart type system definitely leaves room for desire

/// A predicate to determine if the current node is an `Item` or a `Section`
typedef SectionP = bool Function(dynamic b);

/// Given a `Section` node, return a list of children
typedef GetChildren<ZR, ZS> = List<ZR> Function(ZS section);

/// Given a list of children, create a `Section` contianing them
typedef MakeSection<ZR, ZS> = ZS Function(ZS node, List<ZR> children);

/// Poor man's algebraic data type
/// type path =
///   Top
///   | Node of tree list * path * tree list
abstract class Path<T> {
  const Path();
}

/// Top path
@immutable
class TopPath<T> extends Path<T> {}

/// Node path
@immutable
class NodePath<ZS, T> extends Path<T> {
  final List<T> left;
  final List<T> right;
  final Path<T> parentPath;
  final ZS parentNode;

  const NodePath(
      {required this.left,
      required this.right,
      required this.parentPath,
      required this.parentNode});
}

/// The main driver of our implementation
/// We require 3 type parameters to handle the lack of algebraic data types in Dart
/// To use this Zipper you need to define three classes
/// ZR: an abstract root class that both ZI and ZS extend
/// ZI: the item class, leaf nodes of the zipper
/// ZS: the section class, branch classes containing children nodes
@immutable
class ZipperLocation<ZR, ZI extends ZR, ZS extends ZR> {
  final SectionP sectionP;
  final GetChildren<ZR, ZS> getChildren;
  final MakeSection<ZR, ZS> makeSection;
  // dynamic as it can be either ZI or ZS and we lack union types.
  final dynamic node;
  final Path<ZR> path;

  ZipperLocation(
      {required this.sectionP,
      required this.getChildren,
      required this.makeSection,
      required this.node,
      required this.path})
      : assert(node is ZI || node is ZS);

  ZipperLocation.root({
    required this.sectionP,
    required this.getChildren,
    required this.makeSection,
    required this.node,
  })  : assert(node is ZI || node is ZS),
        path = TopPath();

  /// A helper method to copy the definition methods
  ZipperLocation<ZR, ZI, ZS> update(
      {required dynamic node, required Path<ZR> path}) {
    assert(node is ZI || node is ZS);
    return ZipperLocation(
        sectionP: sectionP,
        getChildren: getChildren,
        makeSection: makeSection,
        node: node,
        path: path);
  }

  /// Move to the sibling on the left
  ZipperLocation<ZR, ZI, ZS> goLeft() {
    if (path is TopPath) {
      throw Exception("Left of top");
    }
    NodePath<ZS, ZR> p = path as NodePath<ZS, ZR>;
    if (p.left.isEmpty) {
      throw Exception("left of first");
    }
    ZR l = p.left.first;
    final newLeft = List<ZR>.unmodifiable(p.left.skip(1));
    final newRight = List<ZR>.unmodifiable([node, ...p.right]);
    return update(
      node: l,
      path: NodePath(
        left: newLeft,
        right: newRight,
        parentPath: p.parentPath,
        parentNode: p.parentNode,
      ),
    );
  }

  /// Move to the sibling on the right
  ZipperLocation<ZR, ZI, ZS> goRight() {
    if (path is TopPath) {
      throw Exception("right of top");
    }
    NodePath<ZS, ZR> p = path as NodePath<ZS, ZR>;
    if (p.right.isEmpty) {
      throw Exception("right of last");
    }
    ZR l = p.right.first;
    final newLeft = List<ZR>.unmodifiable([node, ...p.left]);
    final newRight = List<ZR>.unmodifiable(p.right.skip(1));
    return update(
      node: l,
      path: NodePath(
        left: newLeft,
        right: newRight,
        parentPath: p.parentPath,
        parentNode: p.parentNode,
      ),
    );
  }

  /// Move to parent
  ZipperLocation<ZR, ZI, ZS> goUp() {
    if (path is TopPath) {
      throw Exception("up of top");
    }
    NodePath<ZS, ZR> p = path as NodePath<ZS, ZR>;
    List<ZR> cs = List.unmodifiable([...p.left.reversed, node, ...p.right]);

    return update(node: makeSection(p.parentNode, cs), path: p.parentPath);
  }

  /// Move down the tree
  ZipperLocation<ZR, ZI, ZS> goDown() {
    if (!sectionP(node)) {
      throw Exception("down of item");
    }
    final t = node as ZS;
    final cs = getChildren(t);
    if (cs.isEmpty) {
      throw Exception("down of empty");
    }

    return update(
      node: cs.first,
      path: NodePath<ZS, ZR>(
        left: List<ZR>.unmodifiable([]),
        right: List<ZR>.unmodifiable(cs.skip(1)),
        parentPath: path,
        parentNode: node,
      ),
    );
  }

  /// Replace current node
  ZipperLocation<ZR, ZI, ZS> replace(ZR rep) {
    return update(path: path, node: rep);
  }

  /// Insert new node to the right
  ZipperLocation<ZR, ZI, ZS> insertRight(ZR r) {
    if (path is TopPath) {
      throw Exception("insert of top");
    }
    final p = path as NodePath<ZS, ZR>;
    return update(
      node: node,
      path: NodePath(
        left: p.left,
        parentPath: p.parentPath,
        parentNode: p.parentNode,
        right: List.unmodifiable([r, ...p.right]),
      ),
    );
  }

  /// Insert new node to the left
  ZipperLocation<ZR, ZI, ZS> insertLeft(ZR r) {
    if (path is TopPath) {
      throw Exception("insert of top");
    }
    final p = path as NodePath<ZS, ZR>;
    return update(
      node: node,
      path: NodePath(
        left: List.unmodifiable([r, ...p.left]),
        parentPath: p.parentPath,
        parentNode: p.parentNode,
        right: p.right,
      ),
    );
  }

  /// Insert down
  ZipperLocation<ZR, ZI, ZS> insertDown(ZR d) {
    if (!sectionP(node)) {
      throw Exception("down of item");
    }
    final t = node as ZS;

    return update(
      node: d,
      path: NodePath<ZS, ZR>(
        left: List<ZR>.unmodifiable([]),
        parentPath: path,
        parentNode: node,
        right: getChildren(t),
      ),
    );
  }

  /// Remove the current node from the zipper
  /// We first try to move to the right
  /// then to the left, and otherwise up
  ZipperLocation<ZR, ZI, ZS> delete() {
    if (path is TopPath) {
      throw Exception("delete of top");
    }
    final p = path as NodePath<ZS, ZR>;

    if (p.right.isNotEmpty) {
      return update(
        node: p.right.first,
        path: NodePath(
          left: p.left,
          parentPath: p.parentPath,
          parentNode: p.parentNode,
          right: List.unmodifiable(p.right.skip(1)),
        ),
      );
    } else if (p.left.isNotEmpty) {
      return update(
        node: p.left.first,
        path: NodePath(
          left: List.unmodifiable(p.left.skip(1)),
          parentPath: p.parentPath,
          parentNode: p.parentNode,
          right: p.right,
        ),
      );
    } else {
      return update(
        node: makeSection(p.parentNode, List.unmodifiable([])),
        path: p.parentPath,
      );
    }
  }
}
