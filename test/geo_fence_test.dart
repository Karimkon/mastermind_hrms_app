import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/am_visit_model.dart';
import 'package:mastermind_hrms_app/core/services/geo_fence.dart';

/// The verdict the app shows before anybody taps Clock In.
///
/// It has to agree with the server, because the two already disagreed once:
/// the screen measured against the legacy `work_site_lat/lng` pair while the
/// server measured against the mapped `client_sites`, and for one client
/// those are about a kilometre apart. The screen said one thing and the
/// server decided another.
void main() {
  // Kampala industrial area, Lubowa about 9km south-west, and somewhere far
  // enough away that no radius saves it.
  const industrial = [0.3136, 32.5985];
  const lubowa = [0.2489, 32.5561];
  const faraway = [0.4136, 32.5985];

  AmVisitClientModel client({
    required List<List<double>> sites,
    bool enforced = true,
    int radius = 1000,
  }) =>
      AmVisitClientModel(
        id: 1,
        companyName: 'Roofings Uganda Limited',
        geofenceEnforced: enforced,
        sites: [
          for (var i = 0; i < sites.length; i++)
            WorkSiteModel(
              name: i == 0 ? 'Industrial Area' : 'Lubowa',
              lat: sites[i][0],
              lng: sites[i][1],
              radius: radius,
            ),
        ],
      );

  group('distance', () {
    test('matches the real distance between two Kampala points', () {
      final metres = metresBetween(
        industrial[0], industrial[1], lubowa[0], lubowa[1],
      );

      // Roughly 8.5km. Loose bounds on purpose: this guards against the
      // formula being wrong, not against the third decimal place.
      expect(metres, greaterThan(7000));
      expect(metres, lessThan(10000));
    });

    test('is zero at the site itself', () {
      expect(
        metresBetween(industrial[0], industrial[1], industrial[0], industrial[1]),
        lessThan(1),
      );
    });
  });

  group('verdict', () {
    test('an unmapped client is never refused', () {
      final check = checkFence(
        const AmVisitClientModel(id: 1, companyName: 'Uganda Baati'),
        lat: faraway[0],
        lng: faraway[1],
      );

      expect(check.verdict, FenceVerdict.notMapped);
      expect(check.blocksClockIn, isFalse);
    });

    test('no fix yet asks for one rather than judging', () {
      final check = checkFence(client(sites: [industrial]));

      expect(check.verdict, FenceVerdict.noFix);
      expect(check.blocksClockIn, isFalse);
    });

    test('inside the radius is allowed', () {
      final check = checkFence(
        client(sites: [industrial]),
        lat: industrial[0],
        lng: industrial[1],
      );

      expect(check.verdict, FenceVerdict.inside);
      expect(check.blocksClockIn, isFalse);
    });

    test('outside an enforced client is refused', () {
      final check = checkFence(
        client(sites: [industrial]),
        lat: faraway[0],
        lng: faraway[1],
      );

      expect(check.verdict, FenceVerdict.outsideRefused);
      expect(check.blocksClockIn, isTrue);
    });

    /// The flag is what makes refusing safe. A client with one premises
    /// mapped and another not is not ready to turn anybody away.
    test('outside a client that is not marked ready is only flagged', () {
      final check = checkFence(
        client(sites: [industrial], enforced: false),
        lat: faraway[0],
        lng: faraway[1],
      );

      expect(check.verdict, FenceVerdict.outsideFlagged);
      expect(check.blocksClockIn, isFalse);
    });

    /// Roofings has premises at Industrial Area and at Lubowa. Somebody
    /// standing at Lubowa must be judged against Lubowa, not against
    /// whichever site happened to be created first.
    test('the nearest premises wins, not the first', () {
      final check = checkFence(
        client(sites: [industrial, lubowa]),
        lat: lubowa[0],
        lng: lubowa[1],
      );

      expect(check.verdict, FenceVerdict.inside);
      expect(check.nearest!.name, 'Lubowa');
    });
  });

  group('wording', () {
    test('metres below a kilometre, km above', () {
      final near = checkFence(
        client(sites: [industrial], radius: 10),
        lat: industrial[0] + 0.001,
        lng: industrial[1],
      );
      expect(near.distanceLabel, endsWith(' m'));

      final far = checkFence(
        client(sites: [industrial]),
        lat: faraway[0],
        lng: faraway[1],
      );
      expect(far.distanceLabel, endsWith(' km'));
    });
  });
}
